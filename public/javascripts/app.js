(function() {
  $().ready(function() {
    $("a.watch_destroy").click(function(e) {
      var confirm;
      e.preventDefault();
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: $(this).attr("href"),
          data: "_method=delete",
          success: function(watch) {
            return $("tr#watch-" + watch._id).fadeOut();
          }
        });
      }
    });
    $('#new_watch_form').dialog({
      autoOpen: false,
      height: 300,
      width: 350,
      modal: true,
      buttons: {
        '追加': function() {
          var form;
          form = $('form#new_watch');
          return $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: form.serialize(),
            success: function(html) {
              $('#watch_list').append(html);
              return $(this).dialog('close');
            }
          });
        },
        'キャンセル': function() {
          return $(thisObj).dialog('close');
        }
      }
    });
    return $('a.new_watch').click(function(e) {
      e.preventDefault();
      return $('#new_watch_form').dialog('open');
    });
  });
}).call(this);
