# SIWECOS Blacklist Scanner / Initiative-S Scanner

This documentation describes the Blacklist scanner that has been developed as part of SIWECOS.

Initially this scanner was developed for [Initiative-S](https://www.initiative-s.de/).
When Initiative-S was discontinued, the scanner was rewritten for Siwecos.

The scanner regularly fetches known blacklists from the net.

Every checked domain is matched against the blacklists and a report will be generated about each blacklist mentioning the domain.

Depending on the kind of blacklist the score of the domain is reduced.

Current kinds of Blacklists are:

- PHISHING

  The domain was reported to be used in Phishing attempts.

- MALWARE

  The domain was reported to contain or spread Malware.

- SPAM

  The domain was advertised in Spam mails.

## Startup using Docker

`docker run -it --name siwecos-blacklist-scanner -p 2019:8080 -v /PATH/TO/STORAGE:/storage siwecos/ini-s-scanner`

### API-Call

Send a POST-Request to `http://localhost:2019/api/v1/check`:

```shell
curl --data '{
   "url":"https://05p.com",
   "callbackurls":["http://host.docker.internal:9000"],
   "dangerlevel": 10
}' -H 'Content-type: application/json' \
http://localhost:2019/api/v1/check
```

**Note**: You have to have something listening on port 9000 on your docker host for this example.

The parameter `url` is required:

- `url` must be a `string`.

#### Sample output

```json
{
  "name": "INI_S",
  "version": "3.0.0",
  "hasError": false,
  "errorMessage": null,
  "score": 66,
  "tests": [
    {
      "name": "MALWARE",
      "hasError": false,
      "errorMessage": null,
      "score": 0,
      "scoreType": "critical",
      "testDetails": [
        {
          "translationStringId": "DOMAIN_FOUND",
          "placeholders": {
            "DOMAIN": "05p.com",
            "LISTNAME": "hpHosts-Hijacking",
            "LISTURL": "https:\/\/hosts-file.net\/?s=Browse&f=HJK"
          }
        },
        {
          "translationStringId": "DOMAIN_FOUND",
          "placeholders": {
            "DOMAIN": "www.05p.com",
            "LISTNAME": "hpHosts-Hijacking",
            "LISTURL": "https:\/\/hosts-file.net\/?s=Browse&f=HJK"
          }
        }
      ]
    },
    {
      "name": "PHISHING",
      "hasError": false,
      "errorMessage": null,
      "score": 100,
      "scoreType": "success",
      "testDetails": []
    },
    {
      "name": "SPAM",
      "hasError": false,
      "errorMessage": null,
      "score": 100,
      "scoreType": "success",
      "testDetails": []
    }
  ]
}
```

### CLI Command

Direct scanning via CLI is also possible:

`docker run -it --rm -v /PATH/TO/STORAGE:/storage siwecos/ini-s-scanner blacklist get /check/05p.com`

### HTTP-Output-Messages

All tests and results are described in **texts.en.md** (english) and **text.de.md** (german).

## Configuration

The configuration file is **/app/blacklist_checker/etc/blacklist_checker.conf**. It has 3 main sections:

### blacklists

Blacklists are loaded from several sources.
Please refer to the inline documentation given in the configuration file to see how to configure them.

### hypnotoad

The included webserver is [Mojolicious' hypnotoad](https://mojolicious.org/perldoc/Mojo/Server/Hypnotoad).
Its configuration can be set as well.

### minion

[Minion](https://mojolicious.org/perldoc/Minion) is the job queue used.
It requires the location where to store its SQLite database for persisting its job data.

## Environment

These environment variables are used:

- MOJO_MODE

  Defines in which mode to run the application `production` or `development`(default).

- PHISHTANK_API

  It is advised to register an API key for the [Phishtank](https://data.phishtank.com/) blacklist and to set the key using this variable.
  The variable is used in the default **blacklist_checker.conf**.

## Commands

### Startup

The startup is done by **/app/blacklist_checker/script/start**. It will

- download blacklists if they are missing
- start the webserver
- initialize a recurring job to update the blacklists
- start the job queue

Upon first startup, all blacklists will be downloaded.
This will take some time.
The downloaded lists will be persisted to the filesystem in **/storage/blacklists/** (configurable) for faster startup.

### Control

For convenience the main script **/app/blacklist_checker/script/blacklist_checker** is available via a symbolic link in **/usr/local/bin/blacklist**.

Besides the standard commands available in every [Mojolicious](https://mojolicious.org/) application, four commands are available to manage the update job:

- `blacklist list schedule`

  This command is used during startup to initialize an update job.
  Please note that there shouldn't be more than **one** update job.
  This command will not start a new update job as long as there is already one present.

- `blacklist list status`

  This will display information about the last update run.

- `blacklist list show`

  This will list the status of all the blacklists currently in use.

- `blacklist list update`

  This will update all lists without waiting for the next scheduled run.

## Blacklists

Currently 13 blacklists are configured.
Please check **/app/blacklist_checker/etc/blacklist_checker.conf** for details.

The number of blacklists can be extended with (relative) ease.
You just have to give the list a name and need to define from where to download and how to extract the domain names from the downloaded file.
Check the documentation and examples in the default configuration file.

Please note that blacklists shouldn't be downloaded too frequently without contacting the blacklist owners.

Please also note that it is advised to register an API key for the [Phishtank](https://data.phishtank.com/) blacklist and to configure it via the environmant variable `PHISHTANK_API`.

## Errormessage

### Filesystem issues

- `Cannot create` *XXX*`:` *REASON*
- `Failed to rename` *XXX##* `to` *XXX*`:` *REASON*

  The blacklist couldn't be saved to filesystem.
  Check existance of the directories and permissions.
  
- `Cannot read` *XXX*`:` *REASON*

  The blacklist couldn't be read from filesystem.
  Check existance of the file and permissions.

- `Couldn't create` *path_to_storage*`.$index`
- `Failed to save temporary index file`
- `Failed to save index file`

  The scanner couldn't create its index file.
  Check existance of the directories and permissions.

### Configuration issues

- `Missing blacklist id`

  A blacklist needs to have an id, a unique name.

- `Missing blacklist config for` *NAME*

  Each blacklist needs to have a configuration.

- *XXX* `not defined for` *NAME*

  *XXX* can be one of **reader**, **kind**, **reference** or **url**.
  You forgot to define one of these for the blacklist *NAME*.

- `no valid url defined for` *NAME*

  The url for the blacklist *NAME* seems invalid.

- `start` *XXX* `for` *NAME** `is neither a number nor a regexp`

  The `start` property must be a number to denote the line where data starts, or a regular expression to find the line after which data starts.

- `No separator regexp defined for` *NAME*

  In order to split columns, you need to give a regular expression defining the column separartor.

- `header` *sometext* `for` *NAME* `s neither a number nor a regexp`

  The header has to be set to either a number, denoting the line in which the header (of a csv) will be found, or a regular expression matching the header line.

- `header set but no column defined for` *NAME*

  It's required to define in which column the domains will be found.

- `Column 0 for` *NAME* `is not a valid column index. Columns are 1-based``
- `Column` *somenumber* `for` *NAME* `is not a valid column number`

  The column must exist.
  Either a number has to be given or its name.

- `No column in` *NAME* `is labeled $column.`

  The column requested was not found in the blacklist file.

- `Could not parse` *sometext* `with Text::CSV`

  The CSV parser had difficulties "understanding" a line found in the blacklist file.
  Check that you download the correct file and that the file looks as expected.

### Other issues

- `Could not create a Text::CSV reader`

  If this happens it seems as if the CPAN module Text::CSV had an issue.

- *###* `response:` *sometext*

  This happens when the update process couldn't contact a blacklist server.
  It also can happen when the result callback couldn't contact the server.

- `Failed to download` *URL*

  A blacklist couldn't be downloaded

- `Too many redirects for` *URL*

  Usually this is an indicator for a misconfiguration at the blacklist server.
  The server answered with more than the allowed number of redirects.
  Double check with the blacklist owner or refrain from using that blacklist.

- `Could not update` *NAME*

  The update process couldn't download a blacklist.
