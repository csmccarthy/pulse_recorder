

const ad_logic = require('./ad_avoid_logic')
const get_info = ad_logic.get_info
const ad_skip_or_wait = ad_logic.ad_skip_or_wait
const sleep = ad_logic.sleep

const puppeteer = require('puppeteer');
const fs = require('fs')


async function open_window(url, song_num, offset) {
    browser = await puppeteer.launch({
        headless: false,
        ignoreDefaultArgs: [
            "--mute-audio",
        ],
        args: [
            "--autoplay-policy=no-user-gesture-required",
        ],
    });
    const page = await browser.newPage();
    
    const pid = browser.process().pid
    fs.writeFile(`transient/chrome_${Number(song_num)}_pid.txt`, `${pid}`, err => {
        if (err) {
          console.error(err)
          return
        }
        console.log(`song ${song_num} chrome pid logged successfully`)
    })
    await page.goto(url);

    let info_obj = await get_info(page)
    if (info_obj.ad_string) {
        await ad_skip_or_wait(page, info_obj)

        fs.writeFile(`transient/song_${Number(song_num)}_ad_signal.txt`, `${pid}`, err => {
            if (err) {
              console.error(err)
              return
            }
            console.log(`song ${song_num} ad signal written`)
        })
    }
}

async function main(start_idx, urls) {
    for (let i = 0; i < urls.length; i++) {
        const url = urls[i]
        console.log(`opening song ${start_idx + i} chrome window...`)
        open_window(url, start_idx + i, i)
        // await sleep(500)
    }
}
main(Number(process.argv[2]), process.argv.slice(3));