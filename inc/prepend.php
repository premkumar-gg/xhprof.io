<?php
// currently not supported
if(php_sapi_name() == 'cli')
{
	return;
}

if (mt_rand(0, 10000) === 500) {
    xhprof_enable(XHPROF_FLAGS_MEMORY | XHPROF_FLAGS_CPU);
}
