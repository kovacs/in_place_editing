module InPlaceMacrosHelper
  # Makes an HTML element specified by the DOM ID +field_id+ become an in-place
  # editor of a property.
  #
  # A form is automatically created and displayed when the user clicks the element,
  # something like this:
  #   <form id="myElement-in-place-edit-form" target="specified url">
  #     <input name="value" text="The content of myElement"/>
  #     <input type="submit" value="ok"/>
  #     <a onclick="javascript to cancel the editing">cancel</a>
  #   </form>
  # 
  # The form is serialized and sent to the server using an AJAX call, the action on
  # the server should process the value and return the updated value in the body of
  # the reponse. The element will automatically be updated with the changed value
  # (as returned from the server).
  # 
  # Required +options+ are:
  # <tt>:url</tt>::       Specifies the url where the updated value should
  #                       be sent after the user presses "ok".
  # 
  # Addtional +options+ are:
  # <tt>:rows</tt>::              Number of rows (more than 1 will use a TEXTAREA)
  # <tt>:cols</tt>::              Number of characters the text input should span (works for both INPUT and TEXTAREA)
  # <tt>:size</tt>::              Synonym for :cols when using a single line text input.
  # <tt>:cancel_text</tt>::       The text on the cancel link. (default: "cancel")
  # <tt>:save_text</tt>::         The text on the save link. (default: "ok")
  # <tt>:loading_text</tt>::      The text to display while the data is being loaded from the server (default: "Loading...")
  # <tt>:saving_text</tt>::       The text to display when submitting to the server (default: "Saving...")
  # <tt>:external_control</tt>::  The id of an external control used to enter edit mode.
  # <tt>:load_text_url</tt>::     URL where initial value of editor (content) is retrieved.
  # <tt>:options</tt>::           Pass through options to the AJAX call (see prototype's Ajax.Updater)
  # <tt>:with</tt>::              JavaScript snippet that should return what is to be sent
  #                               in the AJAX call, +form+ is an implicit parameter
  # <tt>:script</tt>::            Instructs the in-place editor to evaluate the remote JavaScript response (default: false)
  # <tt>:click_to_edit_text</tt>::The text shown during mouseover the editable text (default: "Click to edit")
  def in_place_editor(field_id, options = {})
    type = options[:collection].nil? ? 'single' : 'collection'
    build_in_place_editor(type, field_id, options)
  end

  EDITORS = {'single' => 'InPlaceEditor',
             'collection' => 'InPlaceCollectionEditor'}

  def build_in_place_editor(type, field_id, options={})
    editor = EDITORS[type]
    function =  "new Ajax.#{editor}("
    function << "'#{field_id}', "
    function << "'#{url_for(options[:url])}'"

    js_options = {}

    if protect_against_forgery?
      options[:with] ||= "Form.serialize(form)"
      options[:with] += " + '&authenticity_token=' + encodeURIComponent('#{form_authenticity_token}')"
    end
    js_options['collection'] = %(#{options[:collection]}) if options[:collection]
    js_options['cancelText'] = %('#{options[:cancel_text]}') if options[:cancel_text]
    js_options['okText'] = %('#{options[:save_text]}') if options[:save_text]
    js_options['loadingText'] = %('#{options[:loading_text]}') if options[:loading_text]
    js_options['savingText'] = %('#{options[:saving_text]}') if options[:saving_text]
    js_options['rows'] = options[:rows] if options[:rows]
    js_options['cols'] = options[:cols] if options[:cols]
    js_options['size'] = options[:size] if options[:size]
    js_options['externalControl'] = "'#{options[:external_control]}'" if options[:external_control]
    js_options['loadTextURL'] = "'#{url_for(options[:load_text_url])}'" if options[:load_text_url]
    js_options['ajaxOptions'] = options_for_javascript(options[:options]) if options[:options]
    js_options['htmlResponse'] = !options[:script] if options[:script]
    js_options['callback']   = options[:callback] if options[:callback]
    if !options[:callback]
      js_options['callback']   = "function(form) { return #{options[:with]} }" if options[:with]
    end
    js_options['onComplete']   = options[:on_complete] if options[:on_complete]
    js_options['onFailure'] = %('#{options[:on_failure]}') if options[:on_failure]
    js_options['clickToEditText'] = %('#{options[:click_to_edit_text]}') if options[:click_to_edit_text]
    js_options['textBetweenControls'] = %('#{options[:text_between_controls]}') if options[:text_between_controls]
    function << (', ' + options_for_javascript(js_options)) unless js_options.empty?
    function << ')'

    javascript_tag(function)
  end
  # Renders the value of the specified object and method with in-place editing capabilities.
  # Updated to be used with RESTful routes. The :url param is inferred from the object type. Also
  # the :callback and :on_complete params are also populated if nothing is provided. The :callback
  # params is populated with a function that sets the form value of the item being edited and
  # included the form_authenticity_token if your app has that setting turned on. The :on_complete
  # parameter takes the response from the update and updates the UI. By default it does a Scriptaculous
  # highlight effect on the field after updating it with the new value.
  # TODO: make it so that failures show validation error messages
  def rest_in_place_editor_field(object, method, tag_options = {}, in_place_editor_options = {})
    tag = ::ActionView::Helpers::InstanceTag.new(object, method, self)
    tag_options = {:tag => "span",
      :id => "#{object}_#{method}_#{tag.object.id}_in_place_editor",
      :class => "in_place_editor_field"}.merge!(tag_options)
    object_name = tag.object.class.to_s.underscore

    # setup restful update URL
    url = "#{url_for(tag.object)}.json"

    in_place_editor_options[:options] ||= {}
    in_place_editor_options[:options][:method] = '"put"'

    in_place_editor_options[:url] = in_place_editor_options[:url] || url

    # send up just the param being updated and the auth token if needed
    callback = "function(form, value) {
                  return '#{object_name}[#{method.to_s}]=' + encodeURIComponent(value)"
    callback += "+ '&authenticity_token=' + encodeURIComponent('#{form_authenticity_token}')" if protect_against_forgery?
    callback += "}"

    in_place_editor_options[:callback] ||= callback

    # update the UI with the updated attribute value
    in_place_editor_options[:on_complete] ||= "function(transport, element) {
                  if (transport && transport.status == 200) {
                    new Effect.Highlight(element.id, {startcolor: \"#00ffff\"});
                    element.innerHTML=transport.responseText.evalJSON().#{tag.object.class.name.demodulize.tableize.singularize}.#{method.to_s};
                  } else {
                    new Effect.Highlight(element.id, {startcolor: \"red\"});
                  }
                }"

    tag.to_content_tag(tag_options.delete(:tag), tag_options) +
      in_place_editor(tag_options[:id], in_place_editor_options)
  end
  
  # Renders the value of the specified object and method with in-place editing capabilities.
  def in_place_editor_field(object, method, tag_options = {}, in_place_editor_options = {})
    tag = ::ActionView::Helpers::InstanceTag.new(object, method, self)
    tag_options = {:tag => "span", :id => "#{object}_#{method}_#{tag.object.id}_in_place_editor", :class => "in_place_editor_field"}.merge!(tag_options)
    in_place_editor_options[:url] = in_place_editor_options[:url] || url_for({ :action => "set_#{object}_#{method}", :id => tag.object.id })
    tag.to_content_tag(tag_options.delete(:tag), tag_options) +
    in_place_editor(tag_options[:id], in_place_editor_options)
  end

  def time_zone_options_for_rest_in_place_select(priority_zones = nil, model = ::ActiveSupport::TimeZone)
    zone_options = ""

    zones = model.all
    convert_zones = lambda { |list| list.map { |z| [ z.name, z.to_s ] } }

    if priority_zones
      zone_values = convert_zones[priority_zones]#.collect {|z| [z.to_s, z.name]}
      zone_values += [['------', '------']]
      the_rest = zones.reject { |z| priority_zones.include?( z ) }
      zone_values += convert_zones[the_rest]
    else
      zone_values = convert_zones[model.all]
    end

    return zone_values.inspect
  end

end
