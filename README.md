PCraw
=====

A web crawler written in Perl.


About the Crawling
==================

When used for the first time, PCraw creates a local repository 
./download/ under the same directory. 
For each download task, a sub directory derived from the url_root 
(see below) will be created, and all downloads are stored there. 

A log file pcraw.log is created under the same directory.  

A cookie file pcrawl_cookie.txt is created under the same directory.

For each download task, at least 1 of 2 parameters below is needed:

1) url_root. This can be provided using the -r switch. Unless the global crawl option -g or 
--global-crawl is specified, only files under this url will be downloaded. If its value is 
not provided, then it uses the domain name part of url_start.

2) url_start. This can be provided using the -u switch. This is the url where the crawling starts from. 
If its value is not provided, it uses url_root as its value.


PCraw uses log files to keep track of crawling progress. If a crawling session is broken, next time starting the crawling  it can pick up from the broken point. It does this by using the following log files stored under local_root (where the downloaded files are stored). When PCraw starts, it first read in values from these 3 logs.

1) .pcraw_lnk_found.log. This stores hash array of the form: url => crawl_depth. The url here can be html files, or any other type of files, like images, audio, video, applications.  The absolute value of crawl_depth is how many levels away from the starting url. If crawl_depth is negative, then the url has not finished crawling; if crawl_depth is positive, then the url has finished crawling. In this log, each url that has been crawled always appear twice: first with negative value, then with positive value (the absolute value is the same, just sign is different). It may appear once with negative value if the file has not been crawled. Note this is similar to the UPDATE operation in a database. Here since we don't use a database, instead write sequentially, we do it this way which essentially is the same as UPDATE. This UPDATE is achieved when PCraw read the entire log at start.

2) .pcraw_[url_start filename]_lnk_Q.log. This stores the array of html links to crawl. Only crawlable html files are stored here.

3) .pcraw_[url_start filename]_lnk_Q_ID.log. This stores the index of current html link being crawled in 2).

2) and 3) are specific to each url_start, they together can track the crawling progress, and make resuming crawl from broken point possible. Note the local_root is created using the value of url_root, under the same url_root there can be different url_start to start crawling from. 1) is global to the entire local_root, such that all the files crawled (no mater html or other types) under url_root are recorded. This way, even if starting from different url_start, the same files can avoid being downloaded again.

Note in 1) we have mentioned each url appears twice, with the same values but different sign, to label the start and finish of crawling the url. This is no longer true in the case of using different url_start (but same url_root) in multiple crawling. When a different url_start is used to start another crawling, it will add new entries about a previously crawled url with different value, the value is the crawl depth of the url in the new crawling session. This should not cause any interference: if a url's value is negative, then it's always picked up for crawling; otherwise if the url's value is positive, it will not be included in the current crawling; the absolute value matters only for the current crawling session and it has been set correctly.


About the Parsing
=================

Parsing of HTML is done by PParse.pm. It extracts text (without tags) and stores in an internal array, and if specified, output the extracted text in a file pparse_out.txt. User can do his own work on the output file.


Usage
=====

Usage: perl pcraw.pl -u <url_start> [-r <url_root>] [-dfghilmoprstuvw]

  Options (short format):  
    -c: wait time (seconds) before crawling next html page.  
    -d: debug, print debug information.  
    -e: default referer when crawling a url, if none exists.  
        This is used when crawling the first page, when no referer exists yet.  
    -f: use flat local path: only one level under local root.  
    -g: allow global crawl outside url_root.  
    -h: print this help message.  
    -i: download non-text files outside the url_root.  
        Used when files are stored outside the url_root.  
    -l: max levels to crawl. Default to 0, 0 means inifinite.  
    -m: file mime type. Only files with given mime types are downloaded.  
        text - 0x1  
        image - 0x2  
        audio - 0x4  
        video - 0x8  
        application - 0x10  
        message - 0x20  
        model - 0x40  
        multipart - 0x80  
        example - 0x100  
        application/vnd - 0x200  
        application/x - 0x400  
        Refer to: http://en.wikipedia.org/wiki/Internet_media_type  
    -n <number_of_links>: the number of links to crawl. 0 means inifinite.  
    -o: overwrite previous download result.  
    -p: parse html. So far just print out text without tags.  
    -r <url_root>: root url.  
        Only files under this path are downloaded. Except when -o is used.  
    -s: only download static pages.   
        Dynamic pages with parameters like http://a.php?a=b are ignored.  
    -u <url_start>: start url.  
        This is where a crawling task starts from.  
    -v: show version information.  
    -w: wait time (seconds) before getting next url. Difference of this   
        with -c is: on each html page, there can be several urls. -c is  
        for each html page, -w is for each url.  

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
    --plain-txt-only: same as -p  
    --referer-default: same as -e  
    --static-only: same as -s  
    --url-root: same as -r  
    --url_start: same as -u  
    --version: same as -v  
    --wait: same as -w  

  The most important options are:  
  -r or --url-root : url_root is needed, and must be provided.  
  -u or --url-start: url_start, when not provided, use url_root as default.  
  
  If an url contains special characters, like space or '&', then
  it should be enclosed with double quotes to work.

  To see perldoc document, type: perldoc pcraw.pl
  
  Examples:  
    perl pcraw.pl -h  
    perl pcraw.pl -r http://a.com   
    perl pcraw.pl -u http://a.com/index.html  
    perl pcraw.pl -r http://a.com -u http://a.com/about.html  
    perl pcraw.pl --url-root http://a.com   
    perl pcraw.pl --url-root http://a.com --url-start http://a.com/  
    perl pcraw.pl --url-root http://a.com -n 1 -m 2 -i -f --min-size 30000  
  
