# PaasMein Web — buyer marketplace demo

This website contains only the buyer experience: a map of demo shops, product
search, shop details, and the Sage bargaining flow. The app handles seller
responses through the Flask relay; there is no seller website.

Start the relay from the repository root:

```sh
cd web
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python server.py
```

Open `http://localhost:5001/` in Safari. The Python virtual environment is local and is not included in Git. The initial search is `gobi`; shop
results are filtered to shops whose demo menu includes the searched item.
The relay address defaults to `http://10.150.28.14:5001` and can be changed
with the settings button on the page. The phone and computer must share Wi-Fi
when the Flutter app responds through the relay.

The relay keeps current negotiations in memory and resets them when stopped.

Android shops are stored on the phone, so they do not appear on this Mac until
the updated PaasMein app syncs them to the relay. The app syncs on shop publish
and when the merchant card opens; keep that screen in the foreground for the
local demo. The webpage checks for new synced shops every five seconds. The
phone and Mac must use the same relay address and Wi-Fi network.
