angular.module("admin.orders").controller 'BulkOrdersCtrl', ($scope, $q, Columns, Dereferencer, Orders, LineItems, Enterprises, OrderCycles, blankOption) ->
  $scope.loading = true
  $scope.saving = false
  $scope.filteredLineItems = []
  $scope.confirmDelete = true
  $scope.startDate = formatDate daysFromToday -7
  $scope.endDate = formatDate daysFromToday 1
  $scope.bulkActions = [ { name: "Delete Selected", callback: $scope.deleteLineItems } ]
  $scope.selectedBulkAction = $scope.bulkActions[0]
  $scope.selectedUnitsProduct = {};
  $scope.selectedUnitsVariant = {};
  $scope.sharedResource = false
  $scope.columns = Columns.setColumns
    order_no:            { name: "Order No.",      visible: false }
    full_name:           { name: "Name",           visible: true }
    email:               { name: "Email",          visible: false }
    phone:               { name: "Phone",          visible: false }
    order_date:          { name: "Order Date",     visible: true }
    producer:            { name: "Producer",       visible: true }
    order_cycle:         { name: "Order Cycle",    visible: false }
    hub:                 { name: "Hub",            visible: false }
    variant:             { name: "Variant",        visible: true }
    quantity:            { name: "Quantity",       visible: true }
    max:                 { name: "Max",            visible: true }
    final_weight_volume: { name: "Weight/Volume",  visible: false }
    price:               { name: "Price",          visible: false }

  $scope.confirmRefresh = ->
    LineItems.allSaved() || confirm("Unsaved changes exist and will be lost if you continue.")

  $scope.refreshData = ->
    $scope.loading = true
    $scope.orders = Orders.index("q[state_not_eq]": "canceled", "q[completed_at_not_null]": "true", "q[completed_at_gt]": "#{$scope.startDate}", "q[completed_at_lt]": "#{$scope.endDate}")
    $scope.distributors = Enterprises.index(action: "for_line_items", serializer: "basic", "q[sells_in][]": ["own", "any"] )
    $scope.orderCycles = OrderCycles.index(serializer: "basic", as: "distributor", "q[orders_close_at_gt]": "#{formatDate(daysFromToday(-90))}")
    $scope.lineItems = LineItems.index("q[state_not_eq]": "canceled", "q[completed_at_not_null]": "true", "q[completed_at_gt]": "#{$scope.startDate}", "q[completed_at_lt]": "#{$scope.endDate}")
    $scope.suppliers = Enterprises.index(action: "for_line_items", serializer: "basic", "q[is_primary_producer_eq]": "true" )

    $q.all([$scope.orders.$promise, $scope.distributors.$promise, $scope.orderCycles.$promise]).then ->
      Dereferencer.dereferenceAttr $scope.orders, "distributor", Enterprises.enterprisesByID
      Dereferencer.dereferenceAttr $scope.orders, "order_cycle", OrderCycles.orderCyclesByID

    $q.all([$scope.orders.$promise, $scope.suppliers.$promise, $scope.lineItems.$promise]).then ->
      Dereferencer.dereferenceAttr $scope.lineItems, "supplier", Enterprises.enterprisesByID
      Dereferencer.dereferenceAttr $scope.lineItems, "order", Orders.ordersByID
      $scope.orderCycles.unshift blankOption()
      $scope.suppliers.unshift blankOption()
      $scope.distributors.unshift blankOption()
      $scope.resetSelectFilters()
      $scope.loading = false


  $scope.refreshData()

  $scope.submit = ->
    if $scope.bulk_order_form.$valid
      $scope.saving = true
      $q.all(LineItems.saveAll()).then ->
        $scope.saving = false
    else
      alert "Some errors must be resolved be before you can update orders.\nAny fields with red borders contain errors."

  $scope.deleteLineItem = (lineItem) ->
    if ($scope.confirmDelete && confirm("Are you sure?")) || !$scope.confirmDelete
      $http(
        method: "DELETE"
        url: "/api/orders/" + lineItem.order.number + "/line_items/" + lineItem.id
      ).success (data) ->
        $scope.lineItems.splice $scope.lineItems.indexOf(lineItem), 1
        delete LineItems.lineItemsByID[lineItem.id]

  $scope.deleteLineItems = (lineItems) ->
    existingState = $scope.confirmDelete
    $scope.confirmDelete = false
    $scope.deleteLineItem lineItem for lineItem in lineItems when lineItem.checked
    $scope.confirmDelete = existingState

  $scope.allBoxesChecked = ->
    checkedCount = $scope.filteredLineItems.reduce (count,lineItem) ->
      count + (if lineItem.checked then 1 else 0 )
    , 0
    checkedCount == $scope.filteredLineItems.length

  $scope.toggleAllCheckboxes = ->
    changeTo = !$scope.allBoxesChecked()
    lineItem.checked = changeTo for lineItem in $scope.filteredLineItems

  $scope.setSelectedUnitsVariant = (unitsProduct,unitsVariant) ->
    $scope.selectedUnitsProduct = unitsProduct
    $scope.selectedUnitsVariant = unitsVariant

  $scope.sumUnitValues = ->
    sum = $scope.filteredLineItems.reduce (sum,lineItem) ->
      sum = sum + lineItem.final_weight_volume
    , 0

  $scope.sumMaxUnitValues = ->
    sum = $scope.filteredLineItems.reduce (sum,lineItem) ->
      sum = sum + Math.max(lineItem.max_quantity,LineItems.pristineByID[lineItem.id].quantity) * lineItem.units_variant.unit_value
    , 0

  $scope.allFinalWeightVolumesPresent = ->
    for i,lineItem of $scope.filteredLineItems
      return false if !lineItem.hasOwnProperty('final_weight_volume') || !(lineItem.final_weight_volume > 0)
    true

  # How is this different to OptionValueNamer#name?
  # Should it be extracted to that class or VariantUnitManager?
  $scope.formattedValueWithUnitName = (value, unitsProduct, unitsVariant) ->
    # A Units Variant is an API object which holds unit properies of a variant
    if unitsProduct.hasOwnProperty("variant_unit") && (unitsProduct.variant_unit == "weight" || unitsProduct.variant_unit == "volume") && value > 0
      scale = VariantUnitManager.getScale(value, unitsProduct.variant_unit)
      Math.round(value/scale * 1000)/1000 + " " + VariantUnitManager.getUnitName(scale, unitsProduct.variant_unit)
    else
      ''

  $scope.fulfilled = (sumOfUnitValues) ->
    # A Units Variant is an API object which holds unit properies of a variant
    if $scope.selectedUnitsProduct.hasOwnProperty("group_buy_unit_size") && $scope.selectedUnitsProduct.group_buy_unit_size > 0 &&
      $scope.selectedUnitsProduct.hasOwnProperty("variant_unit") &&
      ( $scope.selectedUnitsProduct.variant_unit == "weight" || $scope.selectedUnitsProduct.variant_unit == "volume" )
        Math.round( sumOfUnitValues / $scope.selectedUnitsProduct.group_buy_unit_size * 1000)/1000
    else
      ''

  $scope.unitsVariantSelected = ->
    !angular.equals($scope.selectedUnitsVariant,{})

  $scope.resetSelectFilters = ->
    $scope.distributorFilter = $scope.distributors[0].id
    $scope.supplierFilter = $scope.suppliers[0].id
    $scope.orderCycleFilter = $scope.orderCycles[0].id
    $scope.quickSearch = ""

  $scope.weightAdjustedPrice = (lineItem) ->
    if lineItem.final_weight_volume > 0
      unit_value = lineItem.final_weight_volume / lineItem.quantity
      pristine_unit_value = LineItems.pristineByID[lineItem.id].final_weight_volume / LineItems.pristineByID[lineItem.id].quantity
      lineItem.price = LineItems.pristineByID[lineItem.id].price * (unit_value / pristine_unit_value)

  $scope.unitValueLessThanZero = (lineItem) ->
    if lineItem.units_variant.unit_value <= 0
      true
    else
      false

  $scope.updateOnQuantity = (lineItem) ->
    if lineItem.quantity > 0
      lineItem.final_weight_volume = LineItems.pristineByID[lineItem.id].final_weight_volume * lineItem.quantity / LineItems.pristineByID[lineItem.id].quantity
      $scope.weightAdjustedPrice(lineItem)

  $scope.$watch "orderCycleFilter", (newVal, oldVal) ->
    unless $scope.orderCycleFilter == "0" || angular.equals(newVal, oldVal)
      $scope.startDate = OrderCycles.orderCyclesByID[$scope.orderCycleFilter].first_order
      $scope.endDate = OrderCycles.orderCyclesByID[$scope.orderCycleFilter].last_order

daysFromToday = (days) ->
  now = new Date
  now.setHours(0)
  now.setMinutes(0)
  now.setSeconds(0)
  now.setDate( now.getDate() + days )
  now

formatDate = (date) ->
  year = date.getFullYear()
  month = twoDigitNumber date.getMonth() + 1
  day = twoDigitNumber date.getDate()
  return year + "-" + month + "-" + day

formatTime = (date) ->
  hours = twoDigitNumber date.getHours()
  mins = twoDigitNumber date.getMinutes()
  secs = twoDigitNumber date.getSeconds()
  return hours + ":" + mins + ":" + secs

twoDigitNumber = (number) ->
  twoDigits =  "" + number
  twoDigits = ("0" + number) if number < 10
  twoDigits
