(function() {
  $().ready(function() {
    $('a.player_new').live('click', function(e) {
      return open_form_dialog(this, e, {}, {
        success: function(player) {
          var option;
          option = $("<option>").val(player._id).text(player.name);
          return $('#player_select').append(option);
        },
        error: function(err) {
          return alert(err.responseText);
        }
      });
    });
    $('a.player_edit').live('click', function(e) {
      var selected;
      selected = $('#player_select option:selected');
      $(this).attr("href", "/player/" + (selected.val()));
      return open_form_dialog(this, e, {}, {
        success: function(player) {
          var option;
          option = $("<option>").val(player._id).text(player.name);
          selected.replaceWith(option);
          return option.attr("selected", "selected");
        },
        error: function(err) {
          return alert(err.responseText);
        }
      });
    });
    return $('a.player_destroy').live('click', function(e) {
      var confirm, selected;
      e.preventDefault();
      selected = $('#player_select option:selected');
      confirm = window.confirm("本当に削除しますか？");
      if (confirm) {
        return $.ajax({
          type: 'POST',
          url: "/player/" + (selected.val()),
          data: "_method=delete",
          success: function(player) {
            return selected.remove();
          }
        });
      }
    });
  });
}).call(this);
