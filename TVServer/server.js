var app = require('express')();
var http = require('http').createServer(app);
var io = require('socket.io')(http);
const port = 8080;

app.get('/', function(req, res){
    res.sendFile(__dirname + '/index.html');
});

app.get('/watch/:videoId', function(req, res){
    res.sendFile(__dirname + '/video.html');
});

app.get('/videos/:videoId', function(req, res){
  res.sendFile(__dirname + `/videos/${req.params.videoId}.mp4`);
});

app.get('/images/:videoId', function(req, res){
  res.sendFile(__dirname + `/images/${req.params.videoId}.jpg`);
});

const LATENCY_FUDGE = -0.1;
app.get('/progress/:videoId', function(req, res){
    getVideoProgress(Math.random()+"", req.params.videoId, (progress) => {
        console.log(`progress asked for ${req.params.videoId}`);
        res.json({ progress: Math.max(0.0, progress-LATENCY_FUDGE) });
    } )
});

app.get('/restart', function(req, res){
    for(let videoId in clientsRegistered){
        console.log('restart');
        clientsRegistered[videoId].emit('restart', {});
    }
    res.json({ success: true });
});


const clientsRegistered = {}
const waitingForVideoProgress = {}
io.on('connection', function(socket){
    console.log('a user connected');
    socket.on('disconnect', function(){
        console.log('user disconnected');
    });

    socket.on('client-registration', function(msg){
        clientsRegistered[msg.videoId] = socket;
        console.log(`New client connected with video id: ${msg.videoId}`);
    });

    socket.on('client-registration', function(msg){
        clientsRegistered[msg.videoId] = socket;
        console.log(`New client connected with video id: ${msg.videoId}`);
    });

    socket.on('video-progress', function(msg){
        if( waitingForVideoProgress[msg.videoId] !== undefined ){
            waitingForVideoProgress[msg.videoId].forEach( waiter => {
                waiter.cb(msg.progress);
            })

            waitingForVideoProgress[msg.videoId] = [];
        }
    });
});

function getVideoProgress(requestId, videoId, cb){
    if( waitingForVideoProgress[videoId] === undefined ){
        waitingForVideoProgress[videoId] = [];
    };
    waitingForVideoProgress[videoId].push({ requestId, cb });

    if( clientsRegistered[videoId] !== undefined ){
        clientsRegistered[videoId].emit('get-video-progress', {requestId, videoId});
    }
}

http.listen(port, function(){
  console.log(`listening on *:${port}`);
});
