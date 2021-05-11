---
layout: post
title: "From Go to Haskell + Svelte"
---

This post was originally written for <https://levelup.gitconnected.com/from-go-to-haskell-svelte-1ad5ff4a0520>, and I lazily copy pasted it here so some of the formatting is probably off and the images are removed.

From ReactJS, Vue, and Angular to Golang, ExpressJS, and ASP.NET, there are endless combinations for a frontend and backend framework to use when building a web app. Svelte and Haskell are two of the most unique choices for frontend and backend technologies. Svelte, unlike the ubiquitous ReactJS and many of its competitors, doesn’t use a Virtual DOM (VDOM). Haskell is purely functional, as opposed to the primarily imperative Golang, C#, and Java.

I’ve been considering rewriting my personal website from Go to Haskell for a while. While Go is a great server side language, it’s painfully boring. This is an advantage to some, but it’s never appealed to me, especially not for hobby projects. I decided that since I was doing a rewrite anyway, I might as well move from Go’s standard server side templating to Svelte.

## Why Haskell?

Haskell is a purely functional language. Because ofthis, it has:

- an expressive, safe type system
- great type inference
- potentially high parallelism
- concise syntax
- easy refactoring and testing

Unfortunately, there’s a reason Haskell isn’t all that commonly used. Most programmers are taught imperative languages first, making Haskell fairly opaque. It’s also possible to write Haskell programs that are incredibly hard to understand even to experiences Haskell developers. Finally, Haskell is fairly unergonomic for many real world programs since it (correctly) discourages global state. I decided to use Haskell for my server mostly for the fun factor, but also because every endpoint on my site is essentially a pure function.

## Why Svelte?

Svelte’s biggest advantage over other frameworks is that it eschews the VDOM in favor of simply compiling Javascript to update the DOM. This makes it incredibly fast compared to VDOM frameworks. Other advantages include:

- Svelte is easy to learn; components are written in a simple superset of HTML/CSS/JS.
- Great tutorial and easy setup
- Smaller bundle sizes
- Simple and expressive

## Choosing a backend Haskell framework

After deciding the backend language, I still had to choose a web framework. After doing some research and trying some examples, I decided to use Scotty. Scotty is a simple framework inspired by Ruby’s Sinatra. Each endpoint just needs a pattern to match and a Text object to send.

#### Hello Scotty

Here’s the hello world Scotty example from its GitHub page:

```
{-# LANGUAGE OverloadedStrings #-}
import Web.Scotty

import Data.Monoid (mconcat)

main = scotty 3000 $
    get "/:word" $ do
        beam <- param "word"
        html $ mconcat ["<h1>Scotty, ", beam, " me up!</h1>"]
```

I set up my Haskell projects with Stack, which makes things pretty simple. Just run:

stack new {name}
cd {name}
stack setup
stack build

The resulting file tree should be:

```
.
├── app
├── client
│   ├── node_modules
│   ├── public
│   ├── scripts
│   └── src
├── keys
├── src
└── test
```

To add Scotty as a dependency, just add scotty to the list of dependencies in package.yml.

You’ll have to make a few tweaks if you want to use HTTPS and global state, which is necessary for most servers.

```
main :: IO ()
main = do
    let tlsConfig = tlsSettings "keys/fullchain.pem" "keys/privkey.pem"
        config = setPort 8443 defaultSettings

    sync <- newTVarIO def
        -- 'runActionToIO' is called once per action.
    let runActionToIO m = runReaderT (runWebM m) sync

    waiApp <- scottyAppT runActionToIO app
    runTLS tlsConfig config waiApp

app :: ScottyT T.Text WebM  ()
app = dobeam <- param "word"
        html $ mconcat ["<h1>Scotty, ", beam, " me up!</h1>"]
    get "/:word" $ do
        beam <- param "word"
        html $ mconcat ["<h1>Scotty, ", beam, " me up!</h1>"]
```

#### Simple JSON Endpoint

Making JSON with Haskell is super easy using the Aeson library. For my purposes, I just needed to serve a list of records from a local file.

```
import Data.Aesondata RecordType = Image | MP4 | Youtube
data Record = Record { ty :: RecordType, title :: T.Text, url :: T.Text }

instance ToJSON RecordType where
    toJSON Image = "image"
    toJSON MP4 = "mp4"
beam <- param “word”
 html $ mconcat [“<h1>Scotty, “, beam, “ me up!</h1>”]    toJSON Youtube = "youtube"

instance ToJSON Record where
    toJSON (Record {ty=t, title=title, url=u}) = object [ "type" .= t, "title" .= title, "url" .= u]

Just like that, Record is serializeable to JSON! We can serve a Record, or a list of them, pretty easily.

get "/:word" $ do
json $ [Record { ty=Image, title="Hi", url="url" }]
```

As for reading records from a local file, it’s pretty simple. For my toy website, I just read a space separated text file (primitive, I know). However, Haskell has some pretty ergonomic database support. I’ve found this article quite helpful.

Below are the functions that read and write from/to the space separated file. I think they demonstrate the advantages of Haskell compared to other backend languages. The analogue to these functions in Go were nearly a hundred lines long and had a bug in them that I hadn’t noticed.

```
readRecord :: T.Text -> Record
readRecord line = readSplit $ T.splitOn " " $ line
    where readTy :: T.Text -> RecordType
          readTy "image" = Image 
          readTy "MP4" = MP4
          readTy "Youtube" = Youtube
          readTy _ = Image
          readSplit :: [T.Text] -> Record
          readSplit [ty, title, url] = Record {ty=readTy $ T.strip $ ty,title=title, url=url}--            all lines   start   end
readRecords :: [T.Text] -> Int -> Int -> [Record]
readRecords ls start num
  | start >= 0 = map readRecord (take num $ drop start $ ls)
  | otherwise = map readRecord (take num $ drop (-start - num) $ reverse ls)addRecord :: T.Text -> T.Text -> T.Text -> IO ()
addRecord ty title url = do
    let recordLS = map T.unpack [ty, title, url]
    let recordStr = L.intercalate " " recordLS
    file <- SIO.readFile "records.txt"
    writeFile "records.txt" (concat [memeStr, "\n", file])
```

Getting started with Svelte

As mentioned earlier, Svelte’s got some great documentation. The getting started guide tells us that we can start a Svelte project with a few simple commands:

```
npx degit sveltejs/template my-svelte-project
cd my-svelte-project
npm install
npm run dev
```

Next, I skimmed the Svelte tutorial and wrote out my first page. There’s practically no learning curve if you already know HTML/JS. npm run dev rebuilds and hosts the server whenevr you make changes, making iteration speed pretty fast.

```
<script>
    let records = [{type: 'image', title: 'title', url: 'url.com'}]
</script><main>
    <div class="grid">
        {#each records as { type, title, url }, i} 
            {#if type == 'image'}
                <img src='{url}'>
            {:else if type == 'mp4}
                ...
            {/if}
        {/each}
    </div>
</main><style>
...
</style>
```

The snippet above has the records hardcoded in, but realistically you’ll need to fetch them from the server. Luckily, Svelte makes this pretty easy.

```
<script>
    import { onMount } from "svelte"
    
    let records = []    onMount(async () => {
        const res = await fetch('/records')
        records = await res.json()
    })
</script>
```

onMount is a built in Svelte lifecycle even which runs when the page is loaded. Since records is assigned to in the script, it will automatically be updated on the page’s HTML.

This by itself looks quite bad, at least on my website, since the content below the records would flash briefly before the records loaded in. The fix is simple:

```
<script>
    import { onMount, fade } from "svelte"
    
    let records = []
    let loaded = false    onMount(async () => {
        const res = await fetch('/records')
        records = await res.json()
        loaded = true
    })
</script><main>
    {#if loaded}
        <div transition:slide class="grid">
            <!-- Record HTML goes here -->
         </div>
    {/if}
</main>
```

This way, nothing loads in until all the records are ready. Svelte even has a few nice built in transitions, so everything will fade in nicely. If your content takes longer to fetch, it would probably be better to use a loading animation, but that’s pretty easily done with Svelte as well:

```
<main>
    {#if loaded}
        <!-- Record HTML -->
    {:else}
        <!-- Loading Animation -->
    {/if}
</main>
```

Svelte has some animation built in, but I haven’t tried it, and I don’t think it’s intended for loading type animations.

Page.js

One of the limitations of Svelte is that it can only make Single Page Apps*. There is a framework built off of Svelte called Sapper which is meant for multi page websites, but as far as I can tell from minimal research it requires an ExpressJS server. For simplicity, I decided to use a client side router called page.js instead. Initially, I was going to write a simple router by hand, but as page.js is only 1200ish LOC and adds a good bit of ergonomics I decided that it wasn’t worth the effort.

The idea behind using page.js in a Svelte app is pretty simple. Each page just becomes a component, and App.svelte is just a skeleton which could be used for a common header or CSS. Installing page.js is easy: just run npm install page .

Here’s what my new App.svelte looks like:

```
<script>
    import router from "page"
    import Index from './Index.svelte'
    import Records from './Records.svelte'    let page = Index
    
    router('/', () => page = Index)
    router('/records/:p', () => page = Records)
    
    router.start()
</script><main>
    <svelte:component this={page} />
</main><style>Conclusion
</style>
```

Records.svelte is the same as before, line for line, except without the <main> tags since they’re already included in App.svelte. It works with them, but it’s an unnecessary level of nesting.
Hosting the Svelte site from Scotty

Up till now, we’ve been hosting the Svelte app through npm run dev. Instead, we want to host through our Scotty server. Svelte makes this fairly straightforward; running npm run dev will put all of the compiled Svelte HTML/CSS/JS in the public/ folder. Next, all we have to do is make Haskell serve it.

What I decided to do is just add the Svelte folder as a subfolder of my whole Stack project. I renamed it to client, so my file tree looks like:

```
.
├── app
├── client
│   ├── node_modules
│   ├── public
│   ├── scripts
│   └── src
├── src
└── test
```

To make Haskell serve the client/public folder statically, I just added the line middleware $ staticPolicy (noDots >-> addBase “client/public”) at the end of my app function.
Conclusion

The final result is pretty neat; practically all of the JSON endpoints are served as simple pure functions, and Svelte renders them quickly and easily. My server code is now much more succinct and arguably more legible than when it was in Go, and using Svelte as a frontend lets me add some cool effects that weren’t feasible in the server side rendered version. I’m still somewhat opposed to client side rendering in general; I think that sites that can work without JavaScript should make a reasonable effort to. I’ll probably add more interactive stuff to my site at some point though, so I’ll stick with Svelte.

Unfortunately, I probably won’t be using Haskell as a server language again. While a lot of endpoints are just pure functions, I feel like I didn’t get to reap many of the benefits that Haskell usually offers. I am much happier with the Haskell+Svelte version of my site than the Golang version; it’s shorter, more legible, and revealed some bugs in the Golang version that I didn’t even know about. However, the documentation for many Haskell libraries is fairly light, at least with respect to examples, and almost any language is more expressive than Go.
