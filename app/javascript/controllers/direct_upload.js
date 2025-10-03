
// Active Storage direct-upload progress (Rails guide example)
// https://guides.rubyonrails.org/active_storage_overview.html#example
document.addEventListener("direct-uploads:start", event => {
  const { target } = event
  target.classList.add("direct-uploads--active")
})

document.addEventListener("direct-upload:initialize", event => {
  const { target, detail } = event
  const { id, file } = detail

  const progress = document.createElement("div")
  progress.classList.add("direct-upload")
  progress.id = `direct-upload-${id}`
  progress.innerHTML = `
    <div class="direct-upload__progress" style="width: 0%"></div>
    <span class="direct-upload__filename"></span>
  `
  progress.querySelector(".direct-upload__filename").textContent = file.name

  target.insertAdjacentElement("beforebegin", progress)
  target.classList.add("direct-upload--pending")
})

document.addEventListener("direct-upload:start", event => {
  const { id } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  if (element) element.classList.remove("direct-upload--pending")
})

document.addEventListener("direct-upload:progress", event => {
  const { id, progress } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  if (element) element.querySelector(".direct-upload__progress").style.width = `${progress}%`
})

document.addEventListener("direct-upload:error", event => {
  event.preventDefault()
  const { id, error } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  if (element) {
    element.classList.add("direct-upload--error")
    element.setAttribute("title", error)
  }
})

document.addEventListener("direct-uploads:end", event => {
  const { target } = event
  target.classList.remove("direct-uploads--active")
})