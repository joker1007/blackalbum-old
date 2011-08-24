var open_form_dialog;
open_form_dialog = function(sender, e, dialog_options, ajax_callbacks) {
  e.preventDefault();
  return $.ajax({
    type: 'GET',
    url: $(sender).attr('href'),
    success: function(html) {
      var button_option, dom, submit, submit_value, _ref, _ref2;
      dom = $(html);
      submit = dom.find('input[type="submit"]');
      submit_value = submit.val();
      submit.hide();
      button_option = {};
      button_option[submit_value] = function() {
        var form;
        form = dom.children('form');
        $.ajax({
          type: 'POST',
          url: form.attr('action'),
          data: form.serialize(),
          success: ajax_callbacks.success,
          error: ajax_callbacks.error
        });
        return $(this).dialog('close');
      };
      button_option['キャンセル'] = function() {
        return $(this).dialog('close');
      };
      dom.dialog({
        autoOpen: true,
        height: (_ref = dialog_options != null ? dialog_options.height : void 0) != null ? _ref : 300,
        width: (_ref2 = dialog_options != null ? dialog_options.width : void 0) != null ? _ref2 : 600,
        modal: true,
        buttons: button_option
      });
      return dom.find('form').bind('submit', function() {
        return false;
      });
    }
  });
};