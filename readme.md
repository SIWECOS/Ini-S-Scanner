<p align="center"><img src="https://initiative-s.de/images/logo-initiative-s.png"></p>

## About Ini-S Scanner

Initiative-S scanner compares the domain with known blacklists for phishing, malware and spam.

## Installation

Clone this repo.  
Pull from master branch.  
Run in root path, composer update.   
Add in root path, .env file, based on .env.example file.   

## Usage

This app it was designed as a part of [Siwecos Project](https://siwecos.de). That means direct http request isn't functional. Some routes (http request data sensitive), must have a specific bearer token in header authorization. As a part of a project and menat to work with an API, without DB access, the master token it's set as global system variable. Here in repository is set a dummy value for this variable, I strong advise, to modify this value, after deployment in production remote server, based on specific to the project master token. Master token can be foun in config/app.php, section 'Specific app vars', key name 'masterToken'. Dummy value is '12+3456MastErTOkEn78+90s'.  

##### Routes

**Scanner**

**Audit**  
GET audit/today/{type}
- consume: header authorization bearer
- description: get logs for today, based on _type_ - which is optional parameter;  
    * if the type is not set, return all contents;  
    * usual values for {type} could be: all, errors, scanner (or any type set before for logs).
- returns:  
    * 401 Unauthorized. Token provided is not valid. (when the token is not in header of request, or is null, or is not match with 'master token')  
    * 200 OK
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
