
const ad_logic = require('./ad_avoid_logic')
const get_info = ad_logic.get_info
const ad_skip_or_wait = ad_logic.ad_skip_or_wait

const puppeteer = require('puppeteer');
const fs = require('fs')


async function open_window(url, song_num) {
    this.browser = await puppeteer.launch({
        headless: false,
        ignoreDefaultArgs: [
            "--mute-audio",
        ],
        args: [
            "--autoplay-policy=no-user-gesture-required",
        ],
    });
    const page = await browser.newPage();
    await page.goto(url);

    let info_obj = await get_info(page)
    if (info_obj.ad_string) {
        await ad_skip_or_wait(page, info_obj)
    }
    info_obj = await get_info(page)
    this.browser.close();
    const length_arr = info_obj.length.split(':')
    const length_num = (Number(length_arr[0]) * 60) + Number(length_arr[1])
    fs.writeFile(`transient/song_${song_num}_info.txt`, `${info_obj.name}:::${length_num}`, err => {
        if (err) {
          console.error(err)
          return
        }
        console.log(`successfully retrieved song ${song_num} info`)
    })
}

function main(url, song_num) {
    console.log(`gathering song ${song_num} info...`)
    open_window(url, song_num);
}

main(process.argv[2], process.argv[3]);