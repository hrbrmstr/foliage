import { defineConfig } from 'vite'

export default defineConfig({
  base: '/foliage-lit-plot',
  build: {
    target: "esnext",
    lib: {
      entry: 'index.html',
      formats: [ 'es' ],
    },
    esbuild: {
      supported: {
        'top-level-await': true // Browsers can handle top-level-await features
      }
    }
  }
})
