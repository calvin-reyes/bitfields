require 'spec/spec_helper'

class User < ActiveRecord::Base
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
end

class UserWithBitfieldOptions < ActiveRecord::Base
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid, :named_scopes => true
end

class MultiBitUser < ActiveRecord::Base
  set_table_name 'users'
  extend Bitfield
  bitfield :bits, 1 => :seller, 2 => :insane, 4 => :stupid
  bitfield :more_bits, 1 => :one, 2 => :two, 4 => :four
end


describe Bitfield do
  before do
    User.delete_all
  end

  describe :bitfields do
    it "parses them correctly" do
      User.bitfields.should == {:bits => {:seller => 1, :insane => 2, :stupid => 4}}
    end
  end

  describe :bitfield_options do
    it "parses them correctly when not set" do
      User.bitfield_options.should == {:bits => {}}
    end

    it "parses them correctly when set" do
      UserWithBitfieldOptions.bitfield_options.should == {:bits => {:named_scopes => true}}
    end
  end

  describe 'attribute accessors' do
    it "has everything on false by default" do
      User.new.seller.should == false
      User.new.seller?.should == false
    end

    it "is true when set to true" do
      User.new(:seller => true).seller.should == true
    end

    it "is true when set to truthy" do
      User.new(:seller => 1).seller.should == true
    end

    it "is false when set to false" do
      User.new(:seller => false).seller.should == false
    end

    it "is false when set to falsy" do
      User.new(:seller => 'false').seller.should == false
    end

    it "changes the bits when setting to false" do
      user = User.new(:bits => 7)
      user.seller = false
      user.bits.should == 6
    end

    it "does not get negative when unsetting high bits" do
      user = User.new(:seller => true)
      user.stupid = false
      user.bits.should == 1
    end

    it "changes the bits when setting to true" do
      user = User.new(:bits => 2)
      user.seller = true
      user.bits.should == 3
    end

    it "does not get too high when setting high bits" do
      user = User.new(:bits => 7)
      user.seller = true
      user.bits.should == 7
    end
  end

  describe :bitfield_sql do
    it "includes true states" do
      User.bitfield_sql(:insane => true).should == 'users.bits IN (2,3,6,7)' # 2, 1+2, 2+4, 1+2+4
    end

    it "includes invalid states" do
      User.bitfield_sql(:insane => false).should == 'users.bits IN (0,1,4,5)' # 0, 1, 4, 4+1
    end

    it "can combine multiple fields" do
      User.bitfield_sql(:seller => true, :insane => true).should == 'users.bits IN (3,7)' # 1+2, 1+2+4
    end

    it "can combine multiple fields with different values" do
      User.bitfield_sql(:seller => true, :insane => false).should == 'users.bits IN (1,5)' # 1, 1+4
    end

    it "combines multiple columns into one sql" do
      sql = MultiBitUser.bitfield_sql(:seller => true, :insane => false, :one => true, :four => true)
      sql.should == 'users.bits IN (1,5) AND users.more_bits IN (5,7)' # 1, 1+4 AND 1+4, 1+2+4
    end

    it "produces working sql" do
      u1 = MultiBitUser.create!(:seller => true, :one => true)
      u2 = MultiBitUser.create!(:seller => true, :one => false)
      u3 = MultiBitUser.create!(:seller => false, :one => false)
      MultiBitUser.all(:conditions => MultiBitUser.bitfield_sql(:seller => true, :one => false)).should == [u2]
    end
  end

  describe :set_bitfield_sql do
    it "sets a single bit" do
      User.set_bitfield_sql(:seller => true).should == 'bits = (bits | 1) - 0'
    end

    it "unsets a single bit" do
      User.set_bitfield_sql(:seller => false).should == 'bits = (bits | 1) - 1'
    end

    it "sets multiple bits" do
      User.set_bitfield_sql(:seller => true, :insane => true).should == 'bits = (bits | 3) - 0'
    end

    it "unsets multiple bits" do
      User.set_bitfield_sql(:seller => false, :insane => false).should == 'bits = (bits | 3) - 3'
    end

    it "sets and unsets in one command" do
      User.set_bitfield_sql(:seller => false, :insane => true).should == 'bits = (bits | 3) - 1'
    end

    it "sets and unsets for multiple columns in one sql" do
      sql = MultiBitUser.set_bitfield_sql(:seller => false, :insane => true, :one => true, :two => false)
      sql.should == "bits = (bits | 3) - 1, more_bits = (more_bits | 3) - 2"
    end

    it "produces working sql" do
      u = MultiBitUser.create!(:seller => true, :insane => true, :stupid => false, :one => true, :two => false, :four => false)
      sql = MultiBitUser.set_bitfield_sql(:seller => false, :insane => true, :one => true, :two => false)
      MultiBitUser.update_all(sql)
      u.reload
      u.seller.should == false
      u.insane.should == true
      u.stupid.should == false
      u.one.should == true
      u.two.should == false
      u.four.should == false
    end
  end
end