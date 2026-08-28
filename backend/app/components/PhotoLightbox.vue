<script setup lang="ts">
const props = defineProps<{ photos: { url: string }[] }>()

const openIndex = ref<number | null>(null)
const scale = ref(1)
const translate = ref({ x: 0, y: 0 })
const dragging = ref(false)
const dragStart = ref({ x: 0, y: 0 })

function resetView() {
  scale.value = 1
  translate.value = { x: 0, y: 0 }
}

function open(i: number) {
  openIndex.value = i
  resetView()
}

function close() {
  openIndex.value = null
}

function next() {
  if (openIndex.value === null) return
  openIndex.value = (openIndex.value + 1) % props.photos.length
  resetView()
}

function prev() {
  if (openIndex.value === null) return
  openIndex.value = (openIndex.value - 1 + props.photos.length) % props.photos.length
  resetView()
}

function onWheel(e: WheelEvent) {
  e.preventDefault()
  const delta = -e.deltaY * 0.001
  scale.value = Math.min(6, Math.max(0.5, scale.value + delta))
}

function onMouseDown(e: MouseEvent) {
  dragging.value = true
  dragStart.value = { x: e.clientX - translate.value.x, y: e.clientY - translate.value.y }
}

function onMouseMove(e: MouseEvent) {
  if (!dragging.value) return
  translate.value = { x: e.clientX - dragStart.value.x, y: e.clientY - dragStart.value.y }
}

function onMouseUp() {
  dragging.value = false
}

function onKeydown(e: KeyboardEvent) {
  if (openIndex.value === null) return
  if (e.key === 'Escape') close()
  if (e.key === 'ArrowRight') next()
  if (e.key === 'ArrowLeft') prev()
}

onMounted(() => window.addEventListener('keydown', onKeydown))
onUnmounted(() => window.removeEventListener('keydown', onKeydown))

defineExpose({ open })
</script>

<template>
  <Teleport to="body">
    <div
      v-if="openIndex !== null"
      class="lightbox-overlay"
      @click.self="close"
      @wheel="onWheel"
      @mousemove="onMouseMove"
      @mouseup="onMouseUp"
      @mouseleave="onMouseUp"
    >
      <button class="lightbox-close" title="Kapat (Esc)" @click="close">✕</button>
      <button v-if="photos.length > 1" class="lightbox-nav lightbox-prev" title="Önceki (←)" @click.stop="prev">‹</button>
      <button v-if="photos.length > 1" class="lightbox-nav lightbox-next" title="Sonraki (→)" @click.stop="next">›</button>
      <img
        :src="photos[openIndex]?.url"
        class="lightbox-image"
        :class="{ dragging }"
        :style="{ transform: `translate(${translate.x}px, ${translate.y}px) scale(${scale})` }"
        draggable="false"
        @mousedown.prevent="onMouseDown"
      />
      <div class="lightbox-counter">{{ openIndex + 1 }} / {{ photos.length }} — fare tekerleği ile yakınlaştır, sürükle</div>
    </div>
  </Teleport>
</template>

<style scoped>
.lightbox-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.92);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.lightbox-image {
  max-width: 90vw;
  max-height: 85vh;
  user-select: none;
  cursor: grab;
  transition: transform 0.05s ease-out;
}
.lightbox-image.dragging {
  cursor: grabbing;
  transition: none;
}
.lightbox-close,
.lightbox-nav {
  position: absolute;
  background: rgba(255, 255, 255, 0.12);
  border: none;
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}
.lightbox-close:hover,
.lightbox-nav:hover {
  background: rgba(255, 255, 255, 0.22);
}
.lightbox-close {
  top: 16px;
  right: 20px;
  font-size: 18px;
  width: 40px;
  height: 40px;
  border-radius: 50%;
}
.lightbox-nav {
  top: 50%;
  transform: translateY(-50%);
  font-size: 30px;
  width: 48px;
  height: 48px;
  border-radius: 50%;
}
.lightbox-prev {
  left: 20px;
}
.lightbox-next {
  right: 20px;
}
.lightbox-counter {
  position: absolute;
  bottom: 16px;
  left: 50%;
  transform: translateX(-50%);
  color: #fff;
  font-size: 12px;
  background: rgba(255, 255, 255, 0.12);
  padding: 5px 14px;
  border-radius: 999px;
  white-space: nowrap;
}
</style>
