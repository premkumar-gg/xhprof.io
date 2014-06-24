<?php
return array(
	'url_base' => 'http://xhprof.local.giffgaff.com/',
	'url_static' => null, // When undefined, it defaults to $config['url_base'] . 'public/'. This should be absolute URL.
	'pdo' => new PDO('mysql:dbname=sch_xhprof;host=localhost;charset=utf8', 'xhprof', 'qwe123'),
);