$(document).ready(function(){
	$('.url_btn').click(function(){
		$(this).siblings('.project_clone').val($(this).attr('data-clone'));
		$(this).siblings('.url_btn.active').removeClass('active');
		$(this).addClass('active');
	});
	$(".project_clone").click(function () {
  	$(this).select();
	});
	$('.add_btn').click(function(){
		$(this).hide();
		$('.add_repository_form').show();
	});
	$('.close_btn').click(function(){
		$('.add_btn').show();
		$('.add_repository_form').hide();
		$('#repository_url').val('');
	});
	$('.approve_btn').click(function(){
		$('.add_repository_form').submit();
	});
});