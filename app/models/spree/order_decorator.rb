require 'open_food_web/distribution_change_validator'

Spree::Order.class_eval do
  belongs_to :order_cycle
  belongs_to :distributor, :class_name => 'Enterprise'

  before_validation :shipping_address_from_distributor
  validate :products_available_from_new_distribution, :if => lambda { distributor_id_changed? || order_cycle_id_changed? }
  attr_accessible :order_cycle_id, :distributor_id

  before_validation :shipping_address_from_distributor
  before_save :update_line_item_shipping_methods
  after_create :set_default_shipping_method


  def products_available_from_new_distribution
    # Check that the line_items in the current order are available from a newly selected distribution
    errors.add(:base, "Distributor or order cycle cannot supply the products in your cart") unless DistributionChangeValidator.new(self).can_change_to_distribution?(distributor, order_cycle)
  end

  def set_order_cycle!(order_cycle)
    self.order_cycle = order_cycle
    self.distributor = nil unless self.order_cycle.andand.has_distributor? distributor
    save!
  end

  def empty!
    line_items.destroy_all
    adjustments.destroy_all
    set_default_shipping_method
  end

  def set_distributor!(distributor)
    self.distributor = distributor
    self.order_cycle = nil unless self.order_cycle.andand.has_distributor? distributor
    save!
  end

  def set_distribution!(distributor, order_cycle)
    self.distributor = distributor
    self.order_cycle = order_cycle
    save!
  end

  def set_variant_attributes(variant, attributes)
    line_item = find_line_item_by_variant(variant)

    if attributes.key?(:max_quantity) && attributes[:max_quantity].to_i < line_item.quantity
      attributes[:max_quantity] = line_item.quantity
    end

    line_item.assign_attributes(attributes)
    line_item.save!
  end

  def line_item_variants
    line_items.map { |li| li.variant }
  end


  private

  # On creation of the order (when the first item is added to the user's cart), set the
  # shipping method to the first one available and create a shipment.
  # order.shipments.create! creates an adjustment for the shipping cost on the order,
  # which means that the customer can see their shipping cost at every step of the
  # checkout process, not just after the delivery step.
  # This is based on the assumption that there's only one shipping method visible to the user,
  # which is a method using the itemwise shipping calculator.
  def set_default_shipping_method    
    self.shipments.create!(shipping_method: itemwise_shipping_method)
    if self.shipment
      self.save!
    else
      raise 'No default shipping method found'
    end
  end

  def itemwise_shipping_method
    Spree::ShippingMethod.all.find { |sm| sm.calculator.is_a? OpenFoodWeb::Calculator::Itemwise }
  end

  def shipping_address_from_distributor
    if distributor
      self.ship_address = distributor.address.clone

      if bill_address
        self.ship_address.firstname = bill_address.firstname
        self.ship_address.lastname = bill_address.lastname
        self.ship_address.phone = bill_address.phone
      end
    end
  end

  def update_line_item_shipping_methods
    if %w(cart address delivery resumed).include? state
      self.line_items.each { |li| li.update_itemwise_shipping_method_without_callbacks!(distributor) }
      self.update!
    end
  end
end
