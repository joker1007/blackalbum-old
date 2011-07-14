(function() {
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
  $().ready(function() {
    var socket;
    socket = io.connect('localhost');
    socket.on('save_movie', function(data) {
      return $.jGrowl("Saved: " + data.name);
    });
    socket.on('duplicate_movie', function(data) {
      return $.jGrowl("Already Exist: " + data.name);
    });
    socket.on('all_updated', function(target) {
      return $.jGrowl("All Updated: " + target);
    });
    socket.on('player_exit', function(msg) {
      return $.jGrowl(msg);
    });
    $("a.watch_destroy").live('click', function(e) {
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
    $('a.watch_edit').live('click', function(e) {
      return open_form_dialog(this, e, {}, {
        success: function(watch) {
          return $("#watch-" + watch._id + " td.dir").text(watch.dir);
        },
        error: function(err) {
          return alert(err.responseText);
        }
      });
    });
    $('#new_watch_form').dialog({
      autoOpen: false,
      height: 300,
      width: 600,
      modal: true,
      buttons: {
        '追加': function() {
          var form, thisObj;
          thisObj = this;
          form = $('form#new_watch');
          return $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: form.serialize(),
            success: function(html) {
              $('#watch_list').append(html);
              return $(thisObj).dialog('close');
            },
            error: function(err) {
              return alert(err.responseText);
            }
          });
        },
        'キャンセル': function() {
          return $(this).dialog('close');
        }
      }
    });
    $('a.new_watch').live('click', function(e) {
      e.preventDefault();
      $('#new_watch_form').dialog('open');
      return $('form#new_watch').bind('submit', function() {
        return false;
      });
    });
    $('a.movie-play').live('click', function(e) {
      var selected;
      e.preventDefault();
      selected = $('#player_select option:selected');
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "pid=" + (selected.val()),
        success: function(movie) {
          return $.jGrowl("Start Play: " + movie.name);
        }
      });
    });
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
    $('a.player_destroy').live('click', function(e) {
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
    $('a.updatedb').live('click', function(e) {
      e.preventDefault();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        success: function(msg) {
          return $.jGrowl(msg);
        }
      });
    });
    $('a.menu-item').click(function(e) {
      e.preventDefault();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "xhr=true",
        success: function(html) {
          var main;
          main = $('#main');
          main.fadeOut();
          main.queue(function() {
            main.html(html);
            return main.dequeue();
          });
          return main.queue(function() {
            main.fadeIn();
            return main.dequeue();
          });
        }
      });
    });
    return $('.paginator a').live('click', function(e) {
      e.preventDefault();
      return $.ajax({
        type: 'GET',
        url: $(this).attr('href'),
        data: "xhr=true",
        success: function(html) {
          var movies;
          movies = $('.movies');
          movies.fadeOut();
          movies.queue(function() {
            movies.html(html);
            return movies.dequeue();
          });
          return movies.queue(function() {
            movies.fadeIn();
            return movies.dequeue();
          });
        }
      });
    });
  });
}).call(this);
