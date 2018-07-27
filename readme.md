<p align="center"><img src="https://initiative-s.de/images/logo-initiative-s.png"></p>

## About Ini-S Scanner

Initiative-S scanner compares the domain with known blacklists for phishing, malware and spam.

## Server requirements
* [Composer](https://getcomposer.org/) 
* PHP >= 7.1.3
* OpenSSL PHP Extension
* PDO PHP Extension
* Mbstring PHP Extension
* Tokenizer PHP Extension
* XML PHP Extension
* Ctype PHP Extension
* JSON PHP Extension
* in virtual hosts on local/remote server set redirect "web root" to folder **public** or to [subfolder name project]/**public** (only in case the project was installed under a main folder). The file **index.php** from **public** folder is the "front call" fo any HTTP request. 

## Installation

1. Clone this repo.  
2. Pull from master branch.  
3. Run in root path, <code>composer update</code>.   
4. Add in root path, .env file, based on .env.example file.
5. [optional] In root path, generate a cripted key <code>php artisan key:generate</code>, normally this command, should modify automated the .env file. 
6. After install, folders (and their whole contents): **storage** si **bootstrap/cache**, should be free for writing, not just read.

### Configuration

In **config/app.php**, section "Specific app vars", you can found and modify all configuration variables.  
1. "masterToken" - used for header authorization, for some specific security sensitive end-points;
2. "scannerChecks" - major types of blacklists, which scanner check the domain against;
3. "blacklists" - list of blacklists, organised by type and contain all parameters for scrap the custom data provided 

## Usage

This app it was designed as a part of [Siwecos Project](https://siwecos.de). That means direct http request isn't functional. Some routes (http request data sensitive), must have a specific bearer token in header authorization. As a part of a project and meant to work with an API, without DB access, the master token it's set as global system variable. Here in repository is set a dummy value for this variable, we strongly advise, to modify this value, after deployment in production remote server, based on specific to the project master token. Master token can be found in config/app.php, section 'Specific app vars', key name 'masterToken'. Dummy value is "12+3456MastErTOkEn78+90s".  

### Routes

**Scanner**
POST scanner/start
- consume: json object with params  
    ```json
    {
      "url": "http://test.com",	
      "dangerLevel": 0,
      "callbackurls": []
    }
    ```  
- description: start scanning, provided url, against a list of blacklists.
- returns:  
    * _400 Invalid body from POST request_ (when the post json object, that is set to be consumed, is null')
    * _400 No URL is set or given_ (when the post json object exist, but the url is missing, is null, is empty or is not a valid url') 
    * _400 400 No CallBackURLs is set or given_ (when the post json object exist, but the callbacks is missing, or is not a valid array, even empty array')  
    * _200 OK_
        ```json
        {
            "name": "INI_S",
            "hasError": false,
            "score": 66.66666666666667,
            "errorMessage": {
                "placeholder": "NO_ERRORS",
                "values": {}
            },
            "tests": [
                {
                    "name": "PHISHING",
                    "hasError": false,
                    "dangerlevel": 0,
                    "errorMessage": {
                        "placeholder": "NO_ERRORS",
                        "values": {}
                    },
                    "score": 0,
                    "scoreType": "warning",
                    "testDetails": [
                        {
                            "placeholder": "PHISHING_FOUND",
                            "values": {
                                "site": "test.com",
                                "where": "test.com/grp/BofA/verification/action.php?cmd=login_submit&id=205cdb22d9ab1e9f240e78e562a93f8e205cdb22d9ab1e9f240e78e562a93f8e&session=205cdb22d9ab1e9f240e78e562a93f8e205cdb22d9ab1e9f240e78e562a93f8e, test.com/grp/BofA/verification/action2.php?cmd=login_submit&id=b8e7dd50358b8eba106fe6571ab3c880b8e7dd50358b8eba106fe6571ab3c880&session=b8e7dd50358b8eba106fe6571ab3c880b8e7dd50358b8eba106fe6571ab3c880, test.com/grp/BofA/verification/action4.php?cmd=login_submit&id=35373912ae9fcb92cbcff0038474c8d735373912ae9fcb92cbcff0038474c8d7&session=35373912ae9fcb92cbcff0038474c8d735373912ae9fcb92cbcff0038474c8d7, test.com/grp/BofA/verification/login.php?cmd=login_submit&id=MTg0OTkxNDk0NQ==MTg0OTkxNDk0NQ==&session=MTg0OTkxNDk0NQ==MTg0OTkxNDk0NQ=="
                            }
                        }
                    ]
                },
                {
                    "name": "SPAM",
                    "hasError": false,
                    "dangerlevel": 0,
                    "errorMessage": {
                        "placeholder": "NO_ERRORS",
                        "values": {}
                    },
                    "score": 100,
                    "scoreType": "success",
                    "testDetails": []
                },
                {
                    "name": "MALWARE",
                    "hasError": false,
                    "dangerlevel": 0,
                    "errorMessage": {
                        "placeholder": "NO_ERRORS",
                        "values": {}
                    },
                    "score": 100,
                    "scoreType": "success",
                    "testDetails": []
                }
            ]
        }
        ```

**Audit**  
GET audit/today/{type}
- consume: header authorization bearer
- description: get logs for today, based on _type_ - which is optional parameter;  
    * if the {type} is not set, return all contents;  
    * usual values for {type} could be: all, errors, scanner (or any type set before for logs).
- returns:  
    * _401 Unauthorized. Token provided is not valid._ (when the token is not in header of request, or is null, or is not match with 'master token')  
    * _200 OK_
        ```json
        {
            "message": "success",
            "content": [
                "[127.0.0.1][13:34:43] testing 133443"
            ]
        }
        ```

## Security Vulnerabilities

If you discover a security vulnerability within this scanner, please send an e-mail to Botfrei via [technik@initiative-s.de](mailto:technik@initiative-s.de). All security vulnerabilities will be promptly addressed.

## License

The Initiative-S Scanner is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
