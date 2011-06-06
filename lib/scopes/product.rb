module Scopes::Product
  #TODO: change this to array pairs so we preserve order?

  SCOPES = {
    # Scopes for selecting products based on taxon
    :taxon => {
      :taxons_name_eq => [:taxon_name],
      :in_taxons => [:taxon_names],
    },
    # product selection based on name, or search
    :search => {
      :in_name => [:words],
      :in_name_or_keywords => [:words],
      :in_name_or_description => [:words],
      :with_ids => [:ids]
    },
    # Scopes for selecting products based on option types and properties
    :values => {
      :with => [:value],
      :with_property => [:property],
      :with_property_value => [:property, :value],
      :with_option => [:option],
      :with_option_value => [:option, :value],
    },
    # product selection based upon master price
    :price => {
      :price_between => [:low, :high],
      :master_price_lte => [:amount],
      :master_price_gte => [:amount],
    },
  }

  ORDERING = [
    :ascend_by_updated_at,
    :descend_by_updated_at,
    :ascend_by_name,
    :descend_by_name,
    :ascend_by_master_price,
    :descend_by_master_price,
    :descend_by_popularity,
  ]

  ORDERING.each do |name|
    next if %w(asecend_by_master_price descend_by_master_price).include?(name.to_s)
    r = name.to_s.match(/(.*)_by_(.*)/)

    order_text = "products.#{r[2]} "
    order_text << ((r[1] == 'ascend') ?  "asc" : "desc")

    Product.send(:scope, name.to_s, Product.send(:relation).order(order_text) )
  end

  ::Product.scope :ascend_by_master_price, Product.joins(:variants_with_only_master).order('variants.price asc')

  ::Product.scope :descend_by_master_price, Product.joins(:variants_with_only_master).order('variants.price desc')

  ATTRIBUTE_HELPER_METHODS = {
    :with_ids => :product_picker_field
  }

  # Ryan Bates - http://railscasts.com/episodes/112
  # general merging of conditions, names following the searchlogic pattern
  ::Product.scope :conditions, lambda { |*args| {:conditions => args}}

  # conditions_all is a more descriptively named enhancement of the above
  ::Product.scope :conditions_all, lambda { |*args| {:conditions => [args].flatten}}

  # forming the disjunction of a list of conditions (as strings)
  ::Product.scope :conditions_any, lambda { |*args|
    args = [args].flatten
    raise "non-strings in conditions_any" unless args.all? {|s| s.is_a? String}
    {:conditions => args.map {|c| "(#{c})"}.join(" OR ")}
  }


  ::Product.scope :price_between, lambda { |low, high|
    { :joins => :master, :conditions => ["variants.price BETWEEN ? AND ?", low, high] }
  }

  ::Product.scope :master_price_lte, lambda { |price|
    { :joins => :master, :conditions => ["variants.price <= ?", price] }
  }

  ::Product.scope :master_price_gte, lambda { |price|
    { :joins => :master, :conditions => ["variants.price >= ?", price] }
  }


  # This scope selects products in taxon AND all its descendants
  # If you need products only within one taxon use
  #
  #   Product.taxons_id_eq(x)
  #
  ::Product.scope :in_taxon, lambda {|taxon|
    { :joins => :taxons, :conditions => ["taxons.id IN (?) ", taxon.self_and_descendants.map(&:id)]}
  }

  # This scope selects products in all taxons AND all its descendants
  # If you need products only within one taxon use
  #
  #   Product.taxons_id_eq([x,y])
  #
  Product.scope :in_taxons, lambda {|*taxons|
    taxons = get_taxons(taxons)
    taxons.first ? prepare_taxon_conditions(taxons) : {}
  }

  # for quick access to products in a group, WITHOUT using the association mechanism
  Product.scope :in_cached_group, lambda {|product_group|
    { :joins => "JOIN product_groups_products ON products.id = product_groups_products.product_id",
      :conditions => ["product_groups_products.product_group_id = ?", product_group]
    }
  }


  # a scope that finds all products having property specified by name, object or id
  Product.scope :with_property, lambda {|property|
    conditions = case property
    when String   then ["properties.name = ?", property]
    when Property then ["properties.id = ?", property.id]
    else               ["properties.id = ?", property.to_i]
    end

    {
      :joins => :properties,
      :conditions => conditions
    }
  }

  # a scope that finds all products having an option_type specified by name, object or id
  Product.scope :with_option, lambda {|option|
    conditions = case option
    when String     then ["option_types.name = ?", option]
    when OptionType then ["option_types.id = ?",   option.id]
    else                 ["option_types.id = ?",   option.to_i]
    end

    {
      :joins => :option_types,
      :conditions => conditions
    }
  }

  # a simple test for product with a certain property-value pairing
  # note that it can test for properties with NULL values, but not for absent values
  Product.scope :with_property_value, lambda { |property, value|
    conditions = case property
    when String   then ["properties.name = ?", property]
    when Property then ["properties.id = ?", property.id]
    else               ["properties.id = ?", property.to_i]
    end
    conditions = ["product_properties.value = ? AND #{conditions[0]}", value, conditions[1]]

    {
      :joins => :properties,
      :conditions => conditions
    }
  }

  # a scope that finds all products having an option value specified by name, object or id
  Product.scope :with_option_value, lambda {|option, value|
    option_type_id = case option
    when String
      option_type = OptionType.find_by_name(option) || option.to_i
    when OptionType
      option.id
    else
      option.to_i
    end
    conditions = [
      "option_values.name = ? AND option_values.option_type_id = ?",
      value, option_type_id
    ]

    {
      :joins => {:variants => :option_values},
      :conditions => conditions
    }
  }

  # finds product having option value OR product_property
  Product.scope :with, lambda{|value|
    {
      :conditions => ["option_values.name = ? OR product_properties.value = ?", value, value],
      :joins => {:variants => :option_values, :product_properties => []}
    }
  }

  Product.scope :in_name, lambda{|words|
    Product.like_any([:name], prepare_words(words))
  }

  Product.scope :in_name_or_keywords, lambda{|words|
    Product.like_any([:name, :meta_keywords], prepare_words(words))
  }

  Product.scope :in_name_or_description, lambda{|words|
    Product.like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
  }

  Product.scope :with_ids, lambda{|ids|
    ids = ids.split(',') if ids.is_a?(String)
    { :conditions => {:id => ids} }
  }

  # Sorts products from most popular (poularity is extracted from how many
  # times use has put product in cart, not completed orders)
  #
  # there is alternative faster and more elegant solution, it has small drawback though,
  # it doesn stack with other scopes :/
  #
  # :joins => "LEFT OUTER JOIN (SELECT line_items.variant_id as vid, COUNT(*) as cnt FROM line_items GROUP BY line_items.variant_id) AS popularity_count ON variants.id = vid",
  # :order => 'COALESCE(cnt, 0) DESC'
  Product.scope :descend_by_popularity,
    {
      :joins => :master,
      :order => <<SQL
         COALESCE((
           SELECT
             COUNT(line_items.id)
           FROM
             line_items
           JOIN
             variants as popular_variants
           ON
             popular_variants.id = line_items.variant_id
           WHERE
             popular_variants.product_id = products.id
         ), 0) DESC
SQL
    }

  # Produce an array of keywords for use in scopes.
  # Always return array with at least an empty string to avoid SQL errors
  def self.prepare_words(words)
    return [''] if words.blank?
    a = words.split(/[,\s]/).map(&:strip)
    a.any? ? a : ['']
  end

  def self.arguments_for_scope_name(name)
    if group = Scopes::Product::SCOPES.detect{|k,v| v[name.to_sym]}
      group[1][name.to_sym]
    end
  end

  def self.get_taxons(*ids_or_records_or_names)
    ids_or_records_or_names.flatten.map { |t|
      case t
      when Integer then Taxon.find_by_id(t)
      when ActiveRecord::Base then t
      when String
        Taxon.find_by_name(t) ||
        Taxon.find(:first, :conditions => [
          "taxons.permalink LIKE ? OR taxons.permalink = ?", "%/#{t}/", "#{t}/"
        ])
      end
    }.compact.uniq
  end

  # specifically avoid having an order for taxon search (conflicts with main order)
  def self.prepare_taxon_conditions(taxons)
    ids = taxons.map{|taxon| taxon.self_and_descendants.map(&:id)}.flatten.uniq
    { :joins => :taxons, :conditions => ["taxons.id IN (?)", ids] }
  end
end
