import os
import json
import subprocess
from threading import Thread
import asyncio
from secrets import AUTH_KEY


### HTTP HEADER LISTS ###
OPTIONS_HEADERS = [
    [b'access-control-allow-origin', b'*'],
    [b'access-control-allow-methods', b'DELETE, GET, POST, PUT'],
    [b'access-control-max-age', b'172800'],
    [b'allow', b'DELETE, GET, POST, PUT'],
    [b'access-control-allow-headers', b'content-type'],
    [b'date', b'Tue, 10 May 2022 22:59:28 GMT'],
    [b'via', b'1.1 google']
]

MP3_HEADERS = [
    [b'content-type', b'audio/mpeg'],
    [b'access-control-allow-origin', b'*'],
]

TEXT_HEADERS = [
    [b'content-type', b'application/text'],
    [b'access-control-allow-origin', b'*'],
]

JSON_HEADERS = [
    [b'content-type', b'application/json'],
    [b'access-control-allow-origin', b'*']
]

### BODY READING LOGIC ###
async def read_body(receive):
    """
    Read and return the entire body from an incoming ASGI message.
    """
    body = b''
    more_body = True

    while more_body:
        message = await receive()
        body += message.get('body', b'')
        more_body = message.get('more_body', False)

    return json.loads(body.decode('utf-8')) if body else ''


### SEND HANDLERS ###
async def send_status(code, send, headers):
    await send({
        'type': 'http.response.start',
        'status': code,
        'headers': headers,
    })

async def send_ok_status(send, headers):
    await send_status(200, send, headers)

async def send_body(send, body):
    await send({
        'type': 'http.response.body',
        'body': body,
    })



### ENDPOINTS ###
async def handle_download(send, req_body, *args, **kwargs):
    await send_ok_status(send, MP3_HEADERS)

    filename = req_body['filename']
    file = open(f'../scripts/music/{filename}.mp3', 'rb')
    file_b = file.read()
    await send_body(send, file_b)


async def handle_bpm(send, req_body, *args, **kwargs):
    await send_ok_status(send, TEXT_HEADERS)

    filename = req_body['filename']
    with open(f'../scripts/music/{filename}.bpm-tag', 'rb') as f:
        bpm_b = f.read()

    await send_body(send, bpm_b)


async def handle_files(send, *args, **kwargs):
    await send_ok_status(send, JSON_HEADERS)

    body = [ f[:-4] for f in os.listdir('../scripts/music') if f[-8:] != '.bpm-tag']
    body_b = json.dumps(body).encode('utf-8')

    await send_body(send, body_b)


def process_fxn():
    subprocess.call('./record.sh', cwd='../scripts')

async def handle_process(send, req_body, *args, **kwargs):
    processing = os.path.exists('../scripts/transient/processing_signal.txt')

    await send_ok_status(send, JSON_HEADERS)

    has_urls = os.path.getsize('../scripts/urls.txt') != 1
    open_mode = 'a' if processing and has_urls else 'w'
    with open('../scripts/urls.txt', open_mode) as f:
        if open_mode == 'a':
            f.write('\n')
        for idx, url in enumerate(req_body):
            line = f'{url}\n' if idx != len(req_body) - 1 else url
            f.write(line)

    await send_body(send, b'')

    if not processing:
        t = Thread(target=process_fxn)
        t.start()


async def handle_poll(send, *args, **kwargs):
    processing = os.path.exists('../scripts/transient/processing_signal.txt')
    finished = False if processing else os.path.exists('../scripts/transient/finished_signal.txt')

    if not processing and not finished:
        await send_status(404, send, TEXT_HEADERS)
    if processing:
        await send_status(202, send, TEXT_HEADERS)
    if finished:
        os.remove('../scripts/transient/finished_signal.txt')
        await send_status(201, send, TEXT_HEADERS)

    await send_body(send, b'')


async def handle_reset(send, req_body, *args, **kwargs):
    if req_body['auth'] == AUTH_KEY:
        subprocess.call('./reset.sh', cwd='../scripts')
        await send_status(200, send, TEXT_HEADERS)
    else:
        await send_status(401, send, TEXT_HEADERS)

    await send_body(send, b'')


### ROUTER ###
router = {
    '/download': handle_download,
    '/bpm': handle_bpm,
    '/files': handle_files,
    '/process': handle_process,
    '/poll': handle_poll,
    '/reset': handle_reset,
}


### ENTRY POINT ###
async def app(scope, receive, send):
    assert scope['type'] == 'http'

    if scope['method'] == 'OPTIONS':
        await send_ok_status(send, OPTIONS_HEADERS)
        await send_body(send, b'')
    else:
        req_body = await read_body(receive)

        handle_fxn = router.get(scope['path'], lambda **kwargs: None)
        await handle_fxn(send, req_body)
    

