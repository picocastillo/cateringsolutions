module KIOSK
  module ActionViewErrorHelpers
    def error_messages_for(object)
      object = instance_variable_get("@#{object}") unless object.respond_to?(:to_model)
      object = convert_to_model(object)
      render 'error_messages', object: object if object
    end
  end

  module FormBuilderErrorHelpers
    def error_messages
      @template.error_messages_for @object
    end
  end
end

ActiveSupport.on_load(:action_view) { include KIOSK::ActionViewErrorHelpers }
ActionView::Helpers::FormBuilder.include KIOSK::FormBuilderErrorHelpers
