$(function () {
  $("form.delete").submit(function (event) {
    event.preventDefault();
    event.stopPropagation();
    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      // this.submit();
      var form = $(this);
      var request = $.ajax({
        method: form.attr("method"),
        url: form.attr("action"),
      });
      request.done(function (data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
          form.parent("li").remove();
        }
        else if (jqXHR.status === 200) {
          document.location = data;
        }
      });
    }
  });
});