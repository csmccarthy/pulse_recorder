<template>
  <div>
    <header class="header">Downloaded songs:</header>
    <div class="divider"></div>
    <template v-if="!files_loading">
      <div v-for="(file, idx) in files" :key="idx" class="dl-row">
        <div class="file-name">{{ file }}</div>
        <div class="dl-button">
          <a v-if="song_dl !== idx" @click="download(file, idx)">↓</a>
          <div v-else class="dl-loader"></div>
        </div>
      </div>
    </template>
    <template v-if="files_loading || batch_processing">
      <div class="files-loader"></div>
    </template>
    <div style="height: 50px;"></div>
    <header class="header">Put in new batch request:</header>
    <div class="divider"></div>
    <p>Paste urls into the textbox, separating them with only a newline, e.g.</p>
    <div>
      <p style="margin: 0;">http://${process.env.BACKEND_URL}p${process.env.BACKEND_PORT}
      <p style="margin: 0;">http://${process.env.BACKEND_URL}p${process.env.BACKEND_PORT}
      <p style="margin: 0;">http://${process.env.BACKEND_URL}p${process.env.BACKEND_PORT}
    </div>
    <textarea v-model="batch_string" class="batch-text-area"></textarea>
    <div class="url-batch-process" @click="process_batch">
      Process URL batch
    </div>
    <!-- <button class="url-batch-process" @click="process_batch">Process URL batch</button> -->
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'App',
  components: {
  },

  data() {
    return {
      files: [],
      batch_string: '',
      song_dl: null,
      files_loading: true,
      batch_processing: false
    }
  },

  created: async function() {
    console.log(this.files)
    axios.get(
      `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/files`
    ).then(result => {
      console.log(result.data)
      this.files = result.data.sort((a, b) => {
        return a.toLowerCase() > b.toLowerCase() ? 1 : -1
      })
      this.files_loading = false
    })

    this.poll_server(202).then(async still_processing => {
      if (still_processing) {
        this.batch_processing = true
        await this.await_batch()
        this.batch_processing = false
      }
    })
  },

  methods: {
    async retrieve_files() {
      const response = await axios.get(
        `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/files`
      )
      return response.data
    },

    async poll_server(status) {
      return axios.get(
        `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/poll`
      ).then(response => {
        return response.status === status
      }).catch(e => {
        return e.response.status === status
      })
    },

    sleep(ms) {
      return new Promise((resolve) => {
        setTimeout(resolve, ms);
      })
    },

    async download(filename, idx) {
      this.song_dl = idx
      const bpm_response = await axios({
        url: `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/bpm`,
        method: 'POST',
        data: { filename }
      })
      const bpm = bpm_response.data
      const rounded_bpm = Math.round(bpm * 10) / 10
      const file_response = await axios({
        url: `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/download`,
        method: 'POST',
        responseType: 'blob',
        data: { filename }
      })
      const url = window.URL.createObjectURL(new Blob([file_response.data], {
        type: 'audio/mpeg'
      }))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `${rounded_bpm}bpm__${filename}.mp3`)
      document.body.appendChild(link)
      link.click()
      this.song_dl = null
    },

    async await_batch() {

      let done_processing = false
      const timeout = setTimeout(() => {
          alert('Server polling timed out after 10 minutes. If you submitted >8 songs or one of your songs was >10 minutes, check back again later.')
          done_processing = true
      }, 10 * 60 * 1000) // 10 min timeout

      while (!done_processing) {
        console.log('sleeping 60s')
        await this.sleep(60 * 1000) // Poll every minute
        console.log('checking song length')
        done_processing = await this.poll_server(201)
        console.log('songs finished: ', done_processing)
      }
      clearTimeout(timeout)

      return
    },

    async process_batch() {
      const batch_urls = this.batch_string.split('\n')
      if (batch_urls.length === 2 && batch_urls[0] == 'reset') {
        axios.post(
          `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/reset`,
          { auth: batch_urls[1] }
        )
        return
      }

      this.batch_processing = true
      if (batch_urls[batch_urls.length - 1] === '') batch_urls.pop()
      this.batch_string = ''
      axios.post(
        `http://${process.env.BACKEND_URL}:${process.env.BACKEND_PORT}/process`,
        batch_urls
      )

      await this.await_batch()

      this.files = await this.retrieve_files()
      console.log('while loop exited')
      this.batch_processing = false
    }
  }
}
</script>

<style>
.header {
  font-size: 32px;
  font-weight: 700;
}
.divider {
  height: 1px;
  width: 500px;
  background-color: black;
}
.dl-row {
  margin: 10px 0;
  font-size: 28px;
  display: flex;
}
.file-name {
  display: inline-block;
  width: 300px;
}
.dl-button {
  display: inline-block;
  width: 300px;
}
.dl-button a {
  font-weight: 700;
  color: blue;
  cursor: pointer;
  text-decoration: underline;
}
.batch-text-area {
  margin-top: 20px;
  width: 400px;
  height: 200px;
}
.url-batch-process {
  margin-top: 20px;
  border: 2px solid #aaa;
  border-radius: 5px;
  background-color: #ccc;
  width: 200px;
  height: 50px;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
}
.dl-loader {
  border: 2px solid #f3f3f3; /* Light grey */
  border-top: 2px solid #3498db; /* Blue */
  border-radius: 50%;
  width: 20px;
  height: 20px;
  animation: spin 2s linear infinite;
}
.files-loader {
  border: 2px solid #f3f3f3; /* Light grey */
  border-top: 2px solid #3498db; /* Blue */
  border-radius: 50%;
  width: 20px;
  height: 20px;
  animation: spin 2s linear infinite;
  margin: 20px 0 0 200px;
}
.processing-loader {
  border: 2px solid #f3f3f3; /* Light grey */
  border-top: 2px solid #3498db; /* Blue */
  border-radius: 50%;
  width: 20px;
  height: 20px;
  animation: spin 2s linear infinite;
  /* margin: 20px 0 0 200px; */
}
@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
