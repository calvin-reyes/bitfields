Save migrations and columns by storing multiple booleans in a single integer.

    class User < ActiveRecord::Base
      include Bitfields
      bitfield :my_bits, 1 => :seller, 2 => :insane, 4 => :stupid
    end

    user = User.new(:seller => true, :insane => true)
    user.seller == true
    user.stupid? == false
    user.my_bits == 9

 - reader and writers
 - changes `user.chamges == {:seller => [false, true], :insane => [false, true]}`
 - scopes `User.seller.stupid.first` (deactivate with `:scopes => false`)
 - indexable sql via `User.bitfield_sql(:insane => true, :stupid => false) == 'users.my_bits IN (2, 3)' # 2, 1+2`
 - un-indexable sql with `bitfield ... ,:query_mode => :bit_operator` --> `User.bitfield_sql(:insane => true, :stupid => false) == '(users.my_bits & 3) = 1'`
 - setter sql via `User.set_bitfield_sql(:insane => true, :stupid => false) == 'my_bits = (my_bits | 6) - 4'`
 - simple access to bits e.g. `User.bitfields[:my_bits][:stupid] == 4`

Install
=======
As Gem: ` sudo gem install bitfields `  
Or as Rails plugin: ` script/plugins install git://github.com/grosser/bitfields.git `

### Migration
ALWAYS set a default, bitfield queries will not work for NULL
    t.integer :my_bits, :default => 0, :null => false
    OR
    add_column :users, :my_bits, :integer, :default => 0, :null => false

Usage
=====

  User.seller.not_stupid.update_all(User.set_bitfield_sql(:seller => true, :insane => true))

Authors
=======
[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...