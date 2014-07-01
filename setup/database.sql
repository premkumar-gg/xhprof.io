# ************************************************************
# Sequel Pro SQL dump
# Version 4004
#
# http://www.sequelpro.com/
# http://code.google.com/p/sequel-pro/
#
# Host: 127.0.0.1 (MySQL 5.5.30)
# Database: 2012 09 16 xhprof
# Generation Time: 2013-04-14 14:23:23 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table calls
# ------------------------------------------------------------

CREATE DATABASE `xhprof`;

USE `xhprof`;

# Dump of table players
# ------------------------------------------------------------

DROP TABLE IF EXISTS `players`;

CREATE TABLE `players` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table request_data
# ------------------------------------------------------------

DROP TABLE IF EXISTS `request_data`;

CREATE TABLE `request_data` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `hash` varchar(40) NOT NULL,
  `data` blob NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `hash` (`hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table request_hosts
# ------------------------------------------------------------

DROP TABLE IF EXISTS `request_hosts`;

CREATE TABLE `request_hosts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `host` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `host` (`host`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table request_methods
# ------------------------------------------------------------

DROP TABLE IF EXISTS `request_methods`;

CREATE TABLE `request_methods` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `method` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `method` (`method`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table request_uris
# ------------------------------------------------------------

DROP TABLE IF EXISTS `request_uris`;

CREATE TABLE `request_uris` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `uri` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uri` (`uri`),
  KEY `id` (`id`,`uri`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table requests
# ------------------------------------------------------------

DROP TABLE IF EXISTS `requests`;

CREATE TABLE `requests` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `request_host_id` int(10) unsigned NOT NULL,
  `request_uri_id` int(10) unsigned NOT NULL,
  `request_method_id` int(10) unsigned NOT NULL,
  `request_caller_id` int(10) unsigned NOT NULL,
  `https` tinyint(3) unsigned NOT NULL,
  `request_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `request_host_id` (`request_host_id`),
  KEY `request_method_id` (`request_method_id`),
  KEY `request_timestamp` (`request_timestamp`),
  KEY `request_uri_id` (`request_uri_id`,`request_caller_id`),
  KEY `temporary_request_data` (`request_host_id`,`request_uri_id`,`request_method_id`,`request_caller_id`),
  CONSTRAINT `requests_ibfk_3` FOREIGN KEY (`request_method_id`) REFERENCES `request_methods` (`id`) ON DELETE CASCADE,
  CONSTRAINT `requests_ibfk_5` FOREIGN KEY (`request_uri_id`) REFERENCES `request_uris` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `calls_staging`;

CREATE TABLE `calls_staging` (
  `request_id` int(10) unsigned NOT NULL,
  `ct` int(10) unsigned DEFAULT NULL,
  `wt` int(10) unsigned DEFAULT NULL,
  `cpu` int(10) unsigned DEFAULT NULL,
  `mu` int(10) unsigned DEFAULT NULL,
  `pmu` int(10) unsigned DEFAULT NULL,
  `caller` varchar(250) DEFAULT NULL,
  `callee` varchar(250) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `calls`;

CREATE TABLE `calls` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` int(10) unsigned NOT NULL,
  `ct` int(10) unsigned DEFAULT NULL,
  `wt` int(10) unsigned DEFAULT NULL,
  `cpu` int(10) unsigned DEFAULT NULL,
  `mu` int(10) unsigned DEFAULT NULL,
  `pmu` int(10) unsigned DEFAULT NULL,
  `caller_id` int(10) unsigned DEFAULT NULL,
  `callee_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `request_id` (`request_id`),
  CONSTRAINT `calls_ibfk_1` FOREIGN KEY (`request_id`) REFERENCES `requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DELIMITER $$
CREATE PROCEDURE `usp_xhprof_callsStagingToMain`(requestId INT)
BEGIN
	DECLARE callId INT(10);

	INSERT INTO players (`name`)
	SELECT caller
	FROM sch_xhprof.calls_staging AS cs
		LEFT JOIN sch_xhprof.players AS p
			ON IFNULL(cs.caller, '') = p.`name`
	WHERE p.`name` IS NULL 
		AND IFNULL(cs.caller, '') <> ''
		AND cs.request_id = requestId
	GROUP BY caller;

	INSERT INTO players (`name`)
	SELECT callee
	FROM sch_xhprof.calls_staging AS cs
		LEFT JOIN sch_xhprof.players AS p
			ON IFNULL(cs.callee, '') = p.`name`
	WHERE p.`name` IS NULL
		AND IFNULL(cs.caller, '') <> ''
		AND cs.request_id = requestId
	GROUP BY callee;

	INSERT INTO calls (request_id, ct, wt, `cpu`, mu, pmu, caller_id, callee_id)
	SELECT request_id, ct, wt, `cpu`, mu, pmu, 
			callerMap.id AS callerId, calleeMap.id AS calleeId
	FROM sch_xhprof.calls_staging AS stg
		LEFT JOIN players AS callerMap 
			ON IFNULL(stg.caller, '') = callerMap.`name`
		JOIN players AS calleeMap
			ON IFNULL(stg.callee, '') = calleeMap.`name`
	WHERE stg.request_id = requestId;

	SELECT id INTO callId
	FROM sch_xhprof.calls
	WHERE caller_id IS null
		AND request_id = requestId
	ORDER BY id desc
	LIMIT 1;

	UPDATE sch_xhprof.requests 
	SET request_caller_id = callId
	WHERE id = requestId;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE `usp_xhprof_request_ins`(
    requestMethod varchar(10),
    httpHost varchar(255),
    requestUri varchar(255),
    isHttps int(1)
)
BEGIN
    DECLARE requestMethodId int(10);
    DECLARE httpHostId int(10);
    DECLARE requestUriId int(10);
    DECLARE requestId int(10);

    SELECT id INTO requestMethodId
    FROM request_methods
    WHERE method = requestMethod;

    SELECT id INTO httpHostId
    FROM request_hosts
    WHERE `host` = httpHost;

    SELECT id INTO requestUriId
    FROM request_uris
    WHERE uri = requestUri;

    IF requestMethodId IS NULL THEN
        INSERT INTO request_methods SET method = requestMethod;
        SELECT LAST_INSERT_ID() INTO requestMethodId;
    END IF;

    IF httpHostId IS NULL THEN
        INSERT INTO request_hosts SET `host` = httpHost;
        SELECT LAST_INSERT_ID() INTO httpHostId;
    END IF;

    IF requestUriId IS NULL THEN
        INSERT INTO request_uris SET uri = requestUri;
        SELECT LAST_INSERT_ID() INTO requestUriId;
    END IF;

    IF requestMethodId IS NOT NULL AND httpHostId IS NOT NULL AND requestUriId IS NOT NULL THEN
        INSERT INTO requests
            SET request_host_id = httpHostId, 
                request_uri_id = requestUriId, 
                request_method_id = requestMethodId, 
                `https` = isHttps;
        
        SELECT LAST_INSERT_ID() INTO requestId;
    END IF;

	SELECT requestId AS newRequestId;
END$$
DELIMITER ;
