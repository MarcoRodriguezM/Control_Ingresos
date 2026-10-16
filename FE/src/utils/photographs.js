export const maximumPhotographBytes = 5 * 1024 * 1024

const targetPhotographBytes = Math.floor(4.8 * 1024 * 1024)
const allowedPhotographTypes = ['image/jpeg', 'image/png', 'image/webp']

export async function preparePhotograph(file) {
  if (!allowedPhotographTypes.includes(file.type)) {
    throw new Error('La fotografía debe estar en formato JPG, PNG o WebP.')
  }

  const optimized = file.size > maximumPhotographBytes
    ? await compressPhotograph(file)
    : file

  if (optimized.size > maximumPhotographBytes) {
    throw new Error('No fue posible reducir la fotografía a menos de 5 MB.')
  }

  return optimized
}

export function formatFileSize(bytes) {
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`
}

async function compressPhotograph(file) {
  const image = await loadImage(file)
  const canvas = document.createElement('canvas')
  const context = canvas.getContext('2d', { alpha: false })
  if (!context) throw new Error('El navegador no pudo procesar la fotografía.')

  const maximumDimension = 2400
  const initialScale = Math.min(1, maximumDimension / Math.max(image.width, image.height))
  let width = Math.max(1, Math.round(image.width * initialScale))
  let height = Math.max(1, Math.round(image.height * initialScale))
  let quality = 0.9
  let result = null

  for (let attempt = 0; attempt < 14; attempt += 1) {
    canvas.width = width
    canvas.height = height
    context.fillStyle = '#ffffff'
    context.fillRect(0, 0, width, height)
    context.drawImage(image.source, 0, 0, width, height)
    result = await canvasToBlob(canvas, quality)

    if (result.size <= targetPhotographBytes) break
    if (quality > 0.5) quality = Math.max(0.5, quality - 0.1)
    else {
      width = Math.max(1, Math.round(width * 0.82))
      height = Math.max(1, Math.round(height * 0.82))
      quality = 0.82
    }
  }

  image.release()
  if (!result || result.size > maximumPhotographBytes) {
    throw new Error('La fotografía es demasiado grande y no fue posible reducirla a menos de 5 MB.')
  }

  const baseName = file.name.replace(/\.[^.]+$/, '') || 'fotografia'
  return new File([result], `${baseName}-optimizada.jpg`, { type: 'image/jpeg', lastModified: Date.now() })
}

async function loadImage(file) {
  if ('createImageBitmap' in window) {
    const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' })
    return { source: bitmap, width: bitmap.width, height: bitmap.height, release: () => bitmap.close() }
  }

  const url = URL.createObjectURL(file)
  try {
    const element = new Image()
    element.src = url
    await element.decode()
    return { source: element, width: element.naturalWidth, height: element.naturalHeight, release: () => URL.revokeObjectURL(url) }
  } catch (error) {
    URL.revokeObjectURL(url)
    throw error
  }
}

function canvasToBlob(canvas, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => blob ? resolve(blob) : reject(new Error('No fue posible convertir la fotografía.')),
      'image/jpeg',
      quality,
    )
  })
}
