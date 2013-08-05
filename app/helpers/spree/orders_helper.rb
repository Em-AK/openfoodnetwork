module Spree
  module OrdersHelper
    def cart_is_empty
      order = current_order(false)
      order.nil? || order.line_items.empty?
    end

    def order_delivery_fee_subtotal(order, options={})
      options.reverse_merge! :format_as_currency => true
      amount = order.line_items.map { |li| li.itemwise_shipping_cost }.sum
      options.delete(:format_as_currency) ? Spree::Money.new(amount) : amount
    end

    def alternative_available_distributors(order)
      DistributionChangeValidator.new(order).available_distributors(Enterprise.all) - [order.distributor]
    end
  end
end
