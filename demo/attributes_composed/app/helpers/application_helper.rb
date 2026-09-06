module ApplicationHelper
  # Renders the error messages for one attribute of the form builder's object.
  #
  # Works for the Product builder (+inline_errors(form, :price)+) and for a
  # nested +fields_for+ builder whose object is a value object
  # (+inline_errors(address_form, :street)+), because both respond to +errors+.
  def inline_errors(form, attribute)
    object = form.object
    return unless object.respond_to?(:errors)

    messages = object.errors.messages_for(attribute)
    return if messages.empty?

    tag.ul(class: "inline-errors") do
      safe_join(messages.map { |message| tag.li(message) })
    end
  end
end
