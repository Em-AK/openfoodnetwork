module AddToCartHelper
  def product_out_of_stock
    @product.total_on_hand <= 0
  end

  def distributor_available_for?(order, product)
    DistributionChangeValidator.new(order).distributor_available_for?(product)
  end

  def order_cycle_available_for?(order, product)
    DistributionChangeValidator.new(order).order_cycle_available_for?(product)
  end

  def available_distributors_for(order, product)
    DistributionChangeValidator.new(order).available_distributors_for(product)
  end

  def available_order_cycles_for(order, product)
    DistributionChangeValidator.new(order).available_order_cycles_for(product)
  end

end
