# kenmotsu
KML SuperOverlay generator

![social preview image](https://repository-images.githubusercontent.com/509459681/901a4623-dc5d-401d-809f-df035f6ee398)

# Service URLs (open with Google Earth)
- https://x.optgeo.org/kenmotsu/manifold (std, maxzoom=18)
- https://x.optgeo.org/kenmotsu/manifold?maxzoom=17 (std, maxzoom=17)
- https://x.optgeo.org/kenmotsu/manofild?template=https://maps.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png (pale, maxzoom=18)

# social preview image source
https://www.metmuseum.org/art/collection/search/4805

# servitization note
```
[Unit]
Description = unvt.kenmotsu
After = basic.target

[Service]
Type = simple
ExecStart = bash -c 'cd /mnt/hdd/kenmotsu; rake serve'
Restart = alwasy

[Install]
WantedBy = multiuser.target
```

```zsh
sudo systemctl edit --force --full unvt.kenmotsu
sudo systemctl start unvt.kenmotsu
sudo systemctl status unvt.kenmotsu
sudo systemctl enable unvt.kenmotsu
```

