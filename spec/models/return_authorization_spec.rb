require File.dirname(__FILE__) + '/../spec_helper'

describe ReturnAuthorization do

  context 'validation' do
    it  { should have_valid_factory(:return_authorization) }
  end

  let(:inventory_unit) { InventoryUnit.create(:variant => mock_model(Variant)) }
  let(:order) { mock_model(Order, :inventory_units => [inventory_unit], :awaiting_return? => false) }
  let(:return_authorization) { ReturnAuthorization.new(:order => order) }

  before { inventory_unit.stub(:shipped?).and_return(true) }

  context "save" do
    it "should be invalid when order has no inventory units" do
      inventory_unit.stub(:shipped?).and_return(false)
      return_authorization.save
      return_authorization.errors[:order].should == ["has no shipped units"]
    end

    it "should generate RMA number" do
      return_authorization.should_receive(:generate_number)
      return_authorization.save
    end
  end

  context "add_variant" do
    context "on empty rma" do
      it "should associate inventory unit" do
        order.stub(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
        return_authorization.inventory_units.size.should == 1
        inventory_unit.return_authorization.should == return_authorization
      end

      it "should update order state" do
        order.should_receive(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
      end
    end

    context "on rma that already has inventory_units" do
      let(:inventory_unit_2)  { InventoryUnit.create(:variant => inventory_unit.variant) }
      before { order.stub(:inventory_units => [inventory_unit, inventory_unit_2], :awaiting_return? => true) }

      it "should associate inventory unit" do
        order.stub(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 2)
        return_authorization.inventory_units.size.should == 2
        inventory_unit_2.return_authorization.should == return_authorization
      end

      it "should not update order state" do
        order.should_not_receive(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
      end

    end

  end

  context "can_receive?" do
    it "should allow_receive when inventory units assigned" do
      return_authorization.stub(:inventory_units => [inventory_unit])
      return_authorization.can_receive?.should be_true
    end

    it "should not allow_receive with no inventory units" do
      return_authorization.can_receive?.should be_false
    end
  end

  context "receive!" do
    before  do
      inventory_unit.stub(:state => "shipped", :return! => true)
      return_authorization.stub(:inventory_units => [inventory_unit], :amount => -20)
      Adjustment.stub(:create)
      order.stub(:update!)
    end

    it "should mark all inventory units are returned" do
      inventory_unit.should_receive(:return!)
      return_authorization.receive!
    end

    it "should add credit for specified amount" do
      Adjustment.should_receive(:create).with(:source => return_authorization, :order_id => order.id, :amount => -20, :label => I18n.t("rma_credit"))
      return_authorization.receive!
    end

    it "should update order state" do
      order.should_receive :update!
      return_authorization.receive!
    end
  end

  context "force_positive_amount" do
    it "should ensure the amount is always positive" do
      return_authorization.amount = -10
      return_authorization.send :force_positive_amount
      return_authorization.amount.should == 10
    end
  end

  context "after_save" do
    it "should run correct callbacks" do
      return_authorization.should_receive(:force_positive_amount)
      return_authorization.run_callbacks(:save, :after)
    end
  end

end
