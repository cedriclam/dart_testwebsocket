# dart test websocket
dummy project for websocket testing

how to run it
-------------

First you should download dart dependencies
```
pub get
```

Run the server part
```
dart ./bin/websocket.dart -c start
```

Then run client http server
```
pub serve
```

you should be able to access the client in dartium (chromium) at this address: http://localhost:8080/

Opend several tap in you browser in order to see the websocket interaction.
