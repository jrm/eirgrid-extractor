$(document).on('change', ':file', function() {
    var input = $(this),
        numFiles = input.get(0).files ? input.get(0).files.length : 1,
        label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
    input.trigger('fileselect', [numFiles, label]);
});


$(function() {
  
  var files, table;
  var spinner = $( '#process' ).ladda();
  
  var preview = function(data) {
    table = $('#datatable').DataTable( {
        destroy: true,
        data: data.rows,
        columns: [
          { data: 'index', title: "Index" },
          { data: 'ref', title: "Reference" },
          { data: 'size', title: "Size" },                    
          { data: 'project', title: "Project" },
          { data: 'company', title: "Company" },
          { data: 'contact', title: "Contact" },
          { data: 'status', title: "Status" },          
          { data: 'location', title: "Location" },
          { data: 'geo.lat', title: "Lat" },
          { data: 'geo.lng', title: "Lng" }
        ],
        order: [[ 0, "asc" ]]
    });
    $('#results').collapse('show');
    spinner.ladda( 'stop' );
  }
  
  var process = function() {
    spinner.ladda('start')
    var data = new FormData();
    $.each(files, function(key, value) {
      data.append(key, value);
    });
    $.ajax({
      url: '/process',
      type: 'POST',
      data: data,
      cache: false,
      dataType: 'json',
      processData: false, // Don't process the files
      contentType: false, // Set content type to false as jQuery will tell the server its a query string request
      success: function(data, textStatus, jqXHR) {
        if(typeof data.error === 'undefined') {
          preview(data)
          $('#export-csv').attr('href', "/download/" + data.process_id + ".csv")
          $('#export-kml').attr('href', "/download/" + data.process_id + ".kml")
          $('#success-messsge').html(data.rows.length + ' rows extracted').collapse('show')
          console.log('SUCCESS - ' + data.rows.length + ' rows extracted');
        } else {
          $('#error-messsge').html(data.error).collapse('show')
          console.log('ERRORS: ' + data.error);
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {
        $('#error-messsge').html(textStatus).collapse('show')
        console.log('ERRORS: ' + textStatus);
      }
    });
  }
  
  
  $('#process').on('click', process)
  
  $(':file').on('fileselect', function(event, numFiles, label) {
    files = event.target.files;
    $('#filename').val(label)
  });
  
  
});