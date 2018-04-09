CKEDITOR.editorConfig = function( config )
{
    config.resize_minHeight=400;
    config.height=600;

    config.toolbar = [
	{ name: 'styles', items: [ 'Styles', 'Format' ] },
	{ name: 'basicstyles', items: [ 'Bold', 'Italic', 'Underline', 'Strike' ] },
	{ name: 'editing', items: [ 'Scayt' ] },
	{ name: 'paragraph', items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote' ] },
	{ name: 'links', items: [ 'Link', 'Unlink', 'Anchor' ] },
	{ name: 'insert', items: [ 'Image', 'Table', 'HorizontalRule', 'SpecialChar' ] },
	{ name: 'document', items: [ 'Source' ] },
    ];

    config.format_tags='p;h3;h4;h5;pre;div';

};
