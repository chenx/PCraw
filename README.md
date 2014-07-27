PCraw
=====

A web crawler written in Perl.


About the Crawling
==================

PCraw simulates a Firefox browser that accepts cookie. The downloaded files are stored locally in a folder ./download/&lt;local_root&gt;.  The value of local_root is obtained from url_root (see below).


For each download task, at least one of two parameters below is needed:

1) url_root. This can be provided using the -r switch. Unless the global crawl option -g or 
--global-crawl is specified, only files under this url will be downloaded. If its value is 
not provided, then it uses the longest path in url_start.

2) url_start. This can be provided using the -u switch. This is the url where the crawling starts from. 
If its value is not provided, it uses url_root as its value.  The reason to use another parameter url_start in addition to url_root is because under the same url_root one can start from different pages. With 2 parameters it is also easier to specify different sub portions of a domain to crawl.


The other options include:

- For local storage, either create hierachical directory structure (under local_root) the same as the url path, or use flat directory structure (all files under local_root). When flat directory structure is used, files with the same names coming from different folders will be named differently to avoid conflict, e.g., file1.txt, file1_(2).txt, file1_(3).txt ...).  
- Only crawl files under url_root (and under such case, whether to download files not under url_root but directly linked to by files under url_root), or can crawl globally without limit.
- Specify the max level to crawl, starting from url_start
- Specify the max number of html files to crawl, starting from url_start. Note a html file can include many files of different types, here it is about the number of html files.
- Specify the mime type of files to be downloaded. The mime types are specified using OR'd values of 1,2,4,8,.... See more in Usage section.
- Specify the min and max file size to download. This applies only to non-html files. HTML files are always downloaded and parsed for links.
- Whether to overwrite a previous crawl. If not overwrite, it starts from the broken point of the previous crawling session; if overwrite, in mode 1 it starts over again by renaming the prevous folder local_root/ to local_root-2/, in mode 2 it removes the previous folder..
- Specify the wait interval, between crawling each html file, and between crawling each links on the same html file. The default values are 5 seconds for the first, and 1 second for the second.
- Specify whether include dynamic html page (e.g., http://a.com/b.php?c=d), or only include static html files.
- Specify the default referer url. In general all links on a html file use that html url as referer. But at the very beginning the first html file will not have a referer, so specify one here. 
- Specify verbose mode for more details on crawling. Verbose mode 1 will output size and type of downloaded files; verbose mode 2 will output reason if a url is rejected or ignored. To output both, use 3.
 
See Usage section for the command line option switches.



About the Parsing
=================

Parsing of HTML is done by PParse.pm. It extracts text (without tags) and stores in an internal array, and if specified, output the extracted text to a file pparse_out.txt. User can do his own work on the output file.



Usage
=====

Usage: perl pcraw.pl -u <url_start> [-r <url_root>] [-bcdefghilmnoprsuvw]
<pre>
  Options (short format):  
    -b &lt;verbose level number>: print more details of crawling.
        0 (or not specify -b) - print only basic information of urls/links crawled.
        0x1 = 1 - print type/size and file download information.
        0x2 = 2 - print saved file local path.
        0x4 = 4 - print reject/ignore file reason.
    -c &lt;seconds>: wait time (seconds) before crawling next html page.  
    -d: debug, print debug information.  
    -e &lt;default referer>: default referer when crawling a url, if none exists.  
        This is used when crawling the first page, when no referer exists yet.  
    -f: use flat local path: only one level under local root.  
    -g: allow global crawl outside url_root.  
    -h: print this help message.  
    -i &lt;0| |1>: download non-text files outside the url_root. Value is on(1)/off(0). 
        Default is on. Used when some linked files are stored outside the url_root.    
    -l &lt;level number>: max levels to crawl. Default to 0, 0 means inifinite.  
    -m &lt;mime type>: file mime type. Only files with given mime types are downloaded. 
       E.g., to download text and image files, use 0x1 | 0x2 = 3.   
        text  - 0x1 = 1  
        image - 0x2 = 2  
        audio - 0x4 = 4  
        video - 0x8 = 8  
        application - 0x10 = 16  
        message - 0x20 = 32  
        model - 0x40 = 64  
        multipart - 0x80 = 128  
        example - 0x100 = 256  
        application/vnd - 0x200 = 512  
        application/x - 0x400 = 1024  
        Refer to: http://en.wikipedia.org/wiki/Internet_media_type   
    -n &lt;number of links>: the number of links to crawl. 0 means inifinite.  
    -o &lt;0| |1|2>: overwrite previous download result.  
        Values: 0: don't overwrite; 1: move from Dir to Dir-2; 2: remove.  
        When not specify -o, is 0; when use -o without a value, default to 1.  
    -p: parse html. So far just print out text without tags.  
    -r &lt;url_root>: root url. Only files under this are downloaded. 
       Except when -o is used, then crawl globally and there is no limit.  
    -s: only download static pages. Dynamic pages like http://a.php?a=b are ignored.  
    -u &lt;url_start>: start url. This is where a crawling task starts from.  
    -v: show version information.  
    -w &lt;seconds>: wait time (seconds) before getting next url. 
       Difference of this with -c is: on each html page, there can be several urls. 
       -c is for each html page, -w is for each url.  

  Options (long format):  
    --debug: same as -d  
    --flat-localpath: same as -f  
    --global-crawl: same as -g  
    --help: same as -h  
    --inculde-outside-file: same as -i  
    --level-crawl: same as -l  
    --mime_type: same as -m  
    --min-size: min file size to download, in bytes.  
    --max-size: max file size to download, in bytes. 0 means infinite.  
    --number-crawl: same as -t  
    --overwrite: same as -o  
    --parse-html: same as -p  
    --referer-default: same as -e  
    --static-only: same as -s  
    --url-root: same as -r  
    --url_start: same as -u  
    --verbose: same as -b
    --version: same as -v  
    --wait: same as -w  </pre>

  The two most important options are:  
  -r or --url-root : url_root is needed, if not provided, use longest path of url_start.  
  -u or --url-start: url_start, if not provided, use url_root as default.

  At least one of these two must be provided.
  
  If an url contains special characters, like space or '&', then
  it should be enclosed with double quotes to work.

  To see perldoc document, type: perldoc pcraw.pl
  
  Examples:   
<pre>
    // Show help.
    perl pcraw.pl -h  
    
    // Start from default page under a.com, crawl all linked pages in a.com.
    perl pcraw.pl -r http://a.com   

    // Start from index.html, crawl all linked pages in a.com.
    perl pcraw.pl -u http://a.com/index.html  

    // Start from about.html, crawl all linked pages in a.com.
    perl pcraw.pl -r http://a.com -u http://a.com/about.html  

    // Start from the default page under a.com, crawl all linked pages.
    perl pcraw.pl --url-root http://a.com   

    // Start from the about.html page, crawl all linked pages under a.com.
    perl pcraw.pl --url-root http://a.com --url-start http://a.com/about.html    

    // Start from the default page under d/, crawl all linked pages under d/.
    perl pcraw.pl -u http://a.com/b/c/d/

    // Start from the default page under d/, crawl all linked pages under a.com.
    perl pcraw.pl -u http://a.com/b/c/d/ -r http://a.com

    // Crawl only 1 page, and download both text/html and images, where image
    // size should be at least 30000 bytes, and use flat local directory storage
    // instead of default (creating hierarchical directories same as remote path).
    // Also print information of saved and rejected files.
    perl pcraw.pl --url-root http://a.com -n 1 -m 2 -f --min-size 30000 -b 6 

    // Start from default page under a.com, each request of a html page should
    // wait for 10 seconds, each request of a linked non-html file in a page 
    // should wait for 5 seconds. Parse each html page to extract texts (strip 
    // tags) and store in pparse_out.txt.
    perl pcraw.pl -u http://a.com -c 10 -w 5 -p

    // Start from default page under a.com, crawl first 10 html pages.
    perl pcraw.pl -u http://a.com -n 10

    // Start from default page under a.com, crawl all linked files at most 5 levels deep.
    perl pcraw.pl -u http://a.com -l 5

    // Crawl website a.com, backup previous download folder from ./download/a.com/ to 
    // ./download/a.com-2/, or ./download/a.com-3/ if a.com-2/ already exists.
    perl pcraw.pl -u http://a.com -o

    // Crawl website a.com, delete previous download folder ./download/a.com/.
    perl pcraw.pl -u http://a.com -o 2

    // Start from a.com, crawl the entire Internet reachable from here.
    perl pcraw.pl -u http://a.com -g
  </pre>

Implementation Internals
========================

This section shortly gives some details of implementation for interested users.

When used for the first time, PCraw creates a local repository ./download/ under the same directory. 
For each download task, a sub directory derived from the url_root will be created, and all downloads are stored there. 

A log file pcraw.log is created under the same directory.  

A cookie file pcraw_cookie.txt is created under the same directory.

PCraw uses log files to keep track of crawling progress. If a crawling session is broken, next time starting the crawling  it can pick up from the broken point. It does this by using the following log files stored under local_root (where the downloaded files are stored). When PCraw starts, it first read in values from these 3 logs.

1) .pcraw_lnk_found.log. This stores hash array of the form: url => crawl_depth. The url here can be html files, or any other type of files, like images, audio, video, applications.  The absolute value of crawl_depth is how many levels away from the starting url. If crawl_depth is negative, then the url has not finished crawling; if crawl_depth is positive, then the url has finished crawling. In this log, each url that has been crawled always appear twice: first with negative value, then with positive value (the absolute value is the same, just sign is different). It may appear once with negative value if the file has been found (thus url added to link_queue), but has not been crawled. Note this is similar to the UPDATE operation in a database. Here since we don't use a database, instead write sequentially, we do it this way which essentially is the same as UPDATE. This UPDATE is achieved when PCraw read the entire log at start.

2) .pcraw_[url_start filename]_lnk_Q.log. This stores the array of html links to crawl. Only crawlable html files are stored here.

3) .pcraw_[url_start filename]_lnk_Q_ID.log. This stores the index of current html link being crawled in 2).

2) and 3) are specific to each url_start, they together can track the crawling progress, and make resuming crawl from broken point possible. Note the local_root is created using the value of url_root, under the same url_root there can be different url_start to start crawling from. 1) is global to the entire local_root, such that all the files crawled (no mater html or other types) under url_root are recorded. This way, even if starting from different url_start, the same files can avoid being downloaded again.

Note in 1) we have mentioned each url appears twice, with the same values but different sign, to label the start and finish of crawling the url. This may no longer be true in the case of using different url_start (but same url_root) in multiple crawling. When a different url_start is used to start another crawling, it may add new entries about a previously visited (but not crawled) url with different value, the value is the crawl depth of the url in the new crawling session. This should not cause any interference: if a url's value is negative, then it's always picked up for crawling; otherwise if the url's value is positive, it will not be included in the current crawling; the absolute value matters only for the current crawling session and it has been set correctly.

However, there is also a subtle issue involved. Suppose under the same url_root, first crawl with url_start1 and we crawled page p1. Then crawl starting from url_start2, which when come across p1, will give up crawling since p1 was labeled as crawled already. However if file p2 linked to by p1 is not processed yet (we interrupted the first crawling by pressing Ctrl-C), then p2 will not be crawled in the second crawl session. Solutions can include finishing the first crawling, or starting over from beginning in the second crawling using the -o option, which moves the previous local_root/ folder to local_root-2/.


TO DO List
=========

- support specifying wanted file types by file suffix
- robot.txt
- GUI in Java
- recrawl failed urls due to time out
- dynamically change crawl speed for failed urls


======================
Author: X. Chen  
Copyright (C) 2014  
License: Apache/MIT/BSD/GPL  

