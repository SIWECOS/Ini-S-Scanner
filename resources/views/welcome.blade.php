<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>Initiative-S Scanner</title>

    <!-- Fonts -->
    <link href="https://fonts.googleapis.com/css?family=Raleway:100,600" rel="stylesheet" type="text/css">

    <!-- Styles -->
    <style>
        html, body {
            background-color: #fff;
            color: #636b6f;
            font-family: 'Raleway', sans-serif;
            font-weight: 100;
            height: 100vh;
            margin: 0;
        }

        .full-height {
            height: 100vh;
        }

        .flex-center {
            align-items: center;
            display: flex;
            justify-content: center;
        }

        .position-ref {
            position: relative;
        }

        .top-right {
            position: absolute;
            right: 10px;
            top: 18px;
        }

        .content {
            text-align: center;
        }

        .title {
            font-size: 84px;
            text-align: left;
        }

        .m-b-md {
            margin-bottom: 30px;
        }

        .title small{
            font-size: 38px;
        }

        .title small.small-subtitle{
            float: left;
        }

        .title small span {
            display: block;
            width: 100%;
            float: left;
            font-size: 18px;
            padding-top: 110px;
        }
    </style>
</head>
<body>
<div class="flex-center position-ref full-height">
    <div class="content">
        <div class="title m-b-md">
            Initiative-S Scanner<sup><small>2.0</small></sup><br />
            <small class="small-subtitle">Dieser Scanner der Initiative-S gleicht die Domain mit<br />uns bekannten Sperrlisten (Blacklisten)<br />auf Phishing, Malware und Spam ab.<br /><span>powered by Laravel {{ App::VERSION() }}</span></small>
        </div>
    </div>
</div>
</body>
</html>
