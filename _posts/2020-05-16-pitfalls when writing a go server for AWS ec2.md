I've recently been writing a Go server for my my website at [mikail-khan.com](https://mikail-khan.com). I've never used Go, and I've never deployed a server to a domain with https using essentially just a Linux server. Here are a few steps I had difficulty with:

___
### 1. Pointing an HTTPS domain towards a singular EC2 instance

There's plenty of guides around for, especially in the AWS docs, for routing the domain to an Elastic IP using AWS Load Balancers etc., but given that I don't want to pay anything, I just wanted to route everything to a single EC2 instance.

The first thing I tried was to just use the public IPv4 address of the instance in a Hosted Zone Record Set in AWS Route 53, and that does get things part of the way there. Unfortunately, I had my server setup to host on port :8000, so I had to go to mikail-khan.com:8000 to access the site. 

As it turns out, the default port for HTTP is :80 and the default port for HTTPS was :443. I swear I used to know that. The first step in fixing it, of course, was setting the server to host on port :443. Unfortunately, I still couldn't access it just mby typing mikail-khan.com in the browser, I had to use https://mikail-khan.com. I spent a long time trying to fix that and went pretty backwards, but the solution was a three line fix with Go.

All I had to do was redirect requests from the HTTP port (:80) to the HTTPS port (:443). This is done with this function:

```go
func httpRedirect(w http.ResponseWriter, req *http.Request) {
	target := "https://" + req.Host + req.URL.Path
	if len(req.URL.RawQuery) > 0 {
		target += "?" + req.URL.RawQuery
	}
	log.Printf("redirect to %s", target)
	http.Redirect(w, req, target, http.StatusTemporaryRedirect)
}
```

And I added this line at the start of `main()`:
```go
go http.ListenAndServe(":80", http.HandlerFunc(httpRedirect))
```

This is clearly a spot where easily useable green threads are pretty nice.
___

### 2. HTTPS Certificate

This is somewhat a continuation of the first one, but I think it's worth separating. 

Once I'd got mikail-khan.com to point to my EC2 instance, the biggest problem was that browsers marked my site as insecure with a big warning sign to get away from it. This is also something that AWS has plenty of documentation for, but it only really works if you pay. 

I've known about Let's Encrypt for a few months but I've never actually used it. The Certbot script from the site didn't work on the AWS distro the EC2 instance uses, but since I think the distro is just some modification of RHEL/CentOS/Fedora, I tried to just edit the script. Unfortunately, it's a long script and I'm lazy, so I tried to find other solutions.

As it turns out, Certbot is in the package manager repos for the AWS distro, so I installed it with `yum install certbot` and generated the keys pretty easily. From there all I had to do was use this line in my go server:
```go
log.Fatal(http.ListenAndServeTLS(":443", "keys/fullchain.pem", "keys/privkey.pem", server))
```
___

### 3. Go file organization

After I got the very basics of the server down, I wanted to add a new file for extra functionality. I've had problems figuring this out in pretty much every language I've used; regardless of how good the documentation is, I always seem to misunderstand something.

Go, as always, handles this problem pretty simply. All files in the same package have to be in the same folder, and they must have `package {whatever}` at the start of the file. To use anything further, you should create a subdirectory and a new package. There should also be a `go.mod` file which is created with `go mod init {name}`

tl; dr, if I want my main method to be in `main.go` and I want it to use stuff from `extra.go`,
`main.go` could be simplified to:
```go
package main
func main() {
   extra()
}
```

`extra.go` could look like:
```go
package main

import "log"

func Extra() {
   log.Printf("hi\n")
}
```

and you'd probably want a `go.mod` file with:
```
module main
go 1.14
```
It's important to note that all the files would have to be in the same folder, and functions that are used between files have to be capitalized, i.e. `func extra()` isn't get exported out of `extra.go`, but `func Extra()` is.

___

### 4. http.StatusMovedPermanently (301) is cached by the browser

This isn't unique to Go or AWS EC2, but it was a huge pain to debug. Basically I had an endpoint in my server which just did some stuff and then redirected, but the stuff that it did was pretty important. The moment of peak confusion for me was when I turned off my server and the redirect still happened, but it eventually pointed me in the right direction since I realized that the browser must be caching something. My solution was to just switch the status code to http.StatusTemporaryRedirect (307).

In the words of a friend who's much more experienced with writing servers, it's best to "avoid 301s whenever humanly possible."
