

async function get_info(page, delay) {
    if (delay) {
        await sleep(delay)
    }
    let timed_out = false
    const timeout = setTimeout(() => {
        console.log('timeout error')
        timed_out = true
    }, 5000)
    let name
    let length
    let ad_string
    let ad_length_str
    while (!timed_out && (!name && !length) && (!ad_string && !ad_length_str)) {
        try {
            name = await page.$eval('h1.title > yt-formatted-string', el => el.innerText)
            length = await page.$eval('span.ytp-time-duration', el => el.innerText)
            clearTimeout(timeout)
        } catch {}
        try {
            ad_string = await page.$eval('span.ytp-ad-simple-ad-badge > div.ytp-ad-text', el => el.innerText)
            ad_length_str = await page.$eval('span.ytp-ad-duration-remaining > div.ytp-ad-text', el => el.innerText)
            clearTimeout(timeout)
        } catch {}
    }
    return {
        name,
        length,
        ad_string,
        ad_length_str
    }
}

function length_str_to_s(runtime_str) {
    const length_arr = runtime_str.split(':')
    return (Number(length_arr[0]) * 60) + Number(length_arr[1])
}

async function handle_single_ad(page, info_obj) {
    let skip_wait
    try {
        skip_wait = await page.$eval(
            'span.ytp-ad-preview-container.countdown-next-to-thumbnail > div.ytp-ad-text.ytp-ad-preview-text',
            el => el.innerText
        )
    } catch {}

    let sec_remaining = length_str_to_s(info_obj.ad_length_str)
    if (skip_wait && sec_remaining > 7) { // This means we can skip, but the countdown is still going
        await sleep((Number(skip_wait) * 1000) + 1000)
        await page.click('button.ytp-ad-skip-button')
        return true

    } else { // This means the ad isn't skippable and we just have to wait
        await sleep((sec_remaining * 1000) + 3000)
    }
    return false
}

async function ad_skip_or_wait(page, init_info_obj) {
    let info_obj = init_info_obj

    const ad_regex = /Ad (\d+) of (\d+)/g
    const match_arr = [...info_obj.ad_string.matchAll(ad_regex)]

    const num_ads = match_arr && match_arr[0] ? match_arr[0][2] : 1
    for (let i = 0; i < num_ads; i++) {
        const skipped = await handle_single_ad(page, info_obj)
        if (skipped) {
            break
        }
        info_obj = await get_info(page)
    }
}

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

module.exports = {
    get_info,
    length_str_to_s,
    ad_skip_or_wait,
    sleep
}