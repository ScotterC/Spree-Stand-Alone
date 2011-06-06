module Spree::BaseHelper

  def link_to_cart(text = t('cart'))
    return "" if current_page?(cart_path)
    css_class = nil
    if current_order.nil? or current_order.line_items.empty?
      text = "#{text}: (#{t('empty')})"
      css_class = 'empty'
    else
      text = "#{text}: (#{current_order.item_count}) #{order_price(current_order)}"
      css_class = 'full'
    end
    link_to text, cart_path, :class => css_class
  end

  def order_price(order, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
    options.reverse_merge! :format_as_currency => true, :show_vat_text => true

    # overwrite show_vat_text if show_price_inc_vat is false
    options[:show_vat_text] = Spree::Config[:show_price_inc_vat]

    amount =  order.item_total
    amount += Calculator::Vat.calculate_tax(order) if Spree::Config[:show_price_inc_vat]

    options.delete(:format_as_currency) ? number_to_currency(amount) : amount
  end

  def todays_short_date
    utc_to_local(Time.now.utc).to_ordinalized_s(:stub)
  end

  def yesterdays_short_date
    utc_to_local(Time.now.utc.yesterday).to_ordinalized_s(:stub)
  end

  # human readable list of variant options
  def variant_options(v, allow_back_orders = Spree::Config[:allow_backorders], include_style = true)
    list = v.options_text
    list = include_style ? "<span class =\"out-of-stock\">(" + t("out_of_stock") + ") #{list}</span>" : "#{t("out_of_stock")} #{list}" unless (allow_back_orders || v.in_stock?)
    list
  end

  Image.attachment_definitions[:attachment][:styles].each do |style, v|
    define_method "#{style}_image" do |product, *options|
      options = options.first || {}
      if product.images.empty?
        image_tag "noimage/#{style}.jpg", options
      else
        image = product.images.first
        options.reverse_merge! :alt => image.alt.blank? ? product.name : image.alt
        image_tag image.attachment.url(style), options
      end
    end
  end

  def meta_data_tags
    object = instance_variable_get('@'+controller_name.singularize)
    return unless object
    "".tap do |tags|
      if object.respond_to?(:meta_keywords) and object.meta_keywords.present?
        tags << tag('meta', :name => 'keywords', :content => object.meta_keywords) + "\n"
      end
      if object.respond_to?(:meta_description) and object.meta_description.present?
        tags << tag('meta', :name => 'description', :content => object.meta_description) + "\n"
      end
    end
  end

  def stylesheet_tags(paths=stylesheet_paths)
    paths.blank? ? '' : stylesheet_link_tag(paths, :cache => true)
  end

  def stylesheet_paths
    paths = Spree::Config[:stylesheets]
    if (paths.blank?)
      []
    else
      paths.split(',')
    end
  end

  def logo(image_path=Spree::Config[:logo])
    link_to image_tag(image_path), root_path
  end

  def available_countries
    return Country.all unless zone = Zone.find_by_name(Spree::Config[:checkout_zone])
    zone.country_list
  end
  
  def format_price(price, options={})
    options.assert_valid_keys(:show_vat_text)
    options.reverse_merge! :show_vat_text => Spree::Config[:show_price_inc_vat]
    formatted_price = number_to_currency(price)
    if options[:show_vat_text]
      I18n.t(:price_with_vat_included, :price => formatted_price)
    else
      formatted_price
    end
  end
  
  # generates nested url to product based on supplied taxon
  def seo_url(taxon, product = nil)
    return '/t/' + taxon.permalink if product.nil?
    warn "DEPRECATION: the /t/taxon-permalink/p/product-permalink urls are "+
      "not used anymore. Use product_url instead. (called from #{caller[0]})"
    return product_url(product)
  end
  
  def current_orders_product_count
    if current_order.blank? || current_order.item_count < 1
      return 0
    else
      return current_order.item_count
    end
  end

end
