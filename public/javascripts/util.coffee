open_form_dialog = (sender, e, dialog_options, ajax_callbacks) ->
  e.preventDefault()
  $.ajax {
    type: 'GET'
    url: $(sender).attr 'href'
    success: (html) ->
      dom = $(html)
      submit = dom.find('input[type="submit"]')
      submit_value = submit.val()
      submit.hide()
      button_option = {}
      button_option[submit_value] = ->
        form = dom.children 'form'
        $.ajax {
          type: 'POST'
          url: form.attr 'action'
          data: form.serialize()
          success: ajax_callbacks.success
          error: ajax_callbacks.error
        }
        $(this).dialog 'close'
      button_option['キャンセル'] = ->
        $(this).dialog 'close'
      dom.dialog {
        autoOpen: true
        height: dialog_options?.height ? 300
        width: dialog_options?.width ? 600
        modal: true
        buttons: button_option
      }
      dom.find('form').bind 'submit', ->
        return false
  }
