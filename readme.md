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

## Usage

This app it was designed as a part of [Siwecos Project](https://siwecos.de). That means direct http request isn't functional. Some routes (http request data sensitive), must have a specific bearer token in header authorization. As a part of a project and meant to work with an API, without DB access, the master token it's set as global system variable. Here in repository is set a dummy value for this variable, we strongly advise, to modify this value, after deployment in production remote server, based on specific to the project master token. Master token can be found in config/app.php, section 'Specific app vars', key name 'masterToken'. Dummy value is "12+3456MastErTOkEn78+90s".  

### Routes

**Scanner**

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

If you discover a security vulnerability within this scanner, please send an e-mail to Botfrei via [botfrei@eco.de](mailto:botfrei@eco.de). All security vulnerabilities will be promptly addressed.

## License

The Initiative-S Scanner is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
