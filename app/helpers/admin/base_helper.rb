module Admin::BaseHelper

  def field_container(model, method, options = {}, &block)
    unless error_message_on(model, method).blank?
      css_class = 'withError'
    end
    content_tag('p', capture(&block), :class => css_class)
  end

  def error_message_on(object, method, options = {})
    object = convert_to_model(object)
    obj = object.respond_to?(:errors) ? object : instance_variable_get("@#{object}")

    if obj && obj.errors[method].present?
      errors = obj.errors[method].map{|err| h(err)}.join('<br/>').html_safe
      content_tag(:span, errors, :class => 'formError')
    else
      ''
    end
  end

  def spree_date_picker(object, method, options = {}, html_options = {})
    options.merge!(:format => "y-m-d")
    unobtrusive_date_text_picker(object, method, options, html_options)
  end

  def class_for_error(model, method)
    if error_message_on :product, :name
    end
  end

  #You can add additional_fields to the product and variant models. See section 4.2 here: http://spreecommerce.com/documentation/extensions.html
  #If you do choose to add additional_fields, you can utilize the :use parameter to set the input type for any such fields. For example, :use => 'check_box'
  #In the event that you add this functionality, the following method takes care of rendering the proper input type and logic for the supported input-types, which are text_field, check_box, radio_button, and select.
  def get_additional_field_value(controller, field)
    attribute = attribute_name_for(field[:name])

    value = eval("@" + controller.controller_name.singularize + "." + attribute)

    if value.nil? && controller.controller_name == "variants"
      value = @variant.product.has_attribute?(attribute) ? @variant.product[attribute] : nil
    end

    if value.nil?
      return value
    else
      return field.key?(:format) ? sprintf(field[:format], value) : value
    end
  end

  # This method demonstrates the use of the :child_index option to render a
  # form partial for, for instance, client side addition of new nested
  # records.
  #
  # This specific example creates a link which uses javascript to add a new
  # form partial to the DOM.
  #
  #   <%= form_for @project do |project_form| %>
  #     <div id="tasks">
  #       <%= project_form.fields_for :tasks do |task_form| %>
  #         <%= render :partial => 'task', :locals => { :f => task_form } %>
  #       <% end %>
  #     </div>
  #   <% end %>
  def generate_html(form_builder, method, options = {})
    options[:object] ||= form_builder.object.class.reflect_on_association(method).klass.new
    options[:partial] ||= method.to_s.singularize
    options[:form_builder_local] ||= :f

    form_builder.fields_for(method, options[:object], :child_index => 'NEW_RECORD') do |f|
      render(:partial => options[:partial], :locals => { options[:form_builder_local] => f })
    end

  end

  def generate_template(form_builder, method, options = {})
    escape_javascript generate_html(form_builder, method, options)
  end

  def remove_nested(fields)
    out = ''
    out << fields.hidden_field(:_destroy) unless fields.object.new_record?
    out << (link_to icon("delete"), "#", :class => "remove")
    out.html_safe
  end

  def preference_field(form, field, options)
    case options[:type]
    when :integer
      form.text_field(field, {
          :size => 10,
          :class => 'input_integer',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :boolean
      form.check_box(field, {:readonly => options[:readonly],
          :disabled => options[:disabled]})
    when :string
      form.text_field(field, {
          :size => 10,
          :class => 'input_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :password
      form.password_field(field, {
          :size => 10,
          :class => 'password_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :text
      form.text_area(field,
        {:rows => 15, :cols => 85, :readonly => options[:readonly],
          :disabled => options[:disabled]}
      )
    else
      form.text_field(field, {
          :size => 10,
          :class => 'input_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    end
  end

  def preference_fields(object, form)
    return unless object.respond_to?(:preferences)
    object.preferences.keys.map{ |key|
      next unless object.class.preference_definitions.has_key? key

      definition = object.class.preference_definitions[key]
      type = definition.instance_eval{@type}.to_sym

      form.label("preferred_#{key}", t(key)+": ") +
        preference_field(form, "preferred_#{key}", :type => type)
    }.join("<br />").html_safe
  end

  def additional_field_for(controller, field)
     field[:use] ||= 'text_field'
     options = field[:options] || {}

     object_name, method = controller.controller_name.singularize, attribute_name_for(field[:name])

     case field[:use]
     when 'check_box'
       check_box(object_name, method, options, field[:checked_value] || 1, field[:unchecked_value] || 0)
     when 'radio_button'
       html = ''
       field[:value].call(controller, field).each do |value|
         html << radio_button(object_name, method, value, options)
         html << " #{value.to_s} "
       end
       html
     when 'select'
       select(object_name, method, field[:value].call(controller, field), options, field[:html_options] || {})
     else
       value = field[:value] ? field[:value].call(controller, field) : get_additional_field_value(controller, field)
       __send__(field[:use], object_name, method, options.merge(:value => value))
     end # case
   end

  def product_picker_field(name, value)
    products = Product.with_ids(value)
    product_names_hash = products.inject({}){|memo,item| memo[item.id] = item.name; memo}
    %(<input type="text" name="#{name}" value="#{value}" class="tokeninput products" data-names='#{product_names_hash.to_json}' />).html_safe
  end

  # renders set of hidden fields and button to add new record using nested_attributes
  def link_to_add_fields(name, append_to_selector, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, raw("add_fields(\"#{append_to_selector}\", \"#{association}\", \"#{escape_javascript(fields)}\")"), :class => 'add_fields')
  end

  # renders hidden field and link to remove record using nested_attributes
  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to_with_icon(:delete, name, '#', :class => 'remove_fields')
  end

  private
  def attribute_name_for(field_name)
    field_name.gsub(' ', '_').downcase
  end

end
