document.addEventListener('DOMContentLoaded', () => {
  const yearElement = document.getElementById('currentYear');

  if (yearElement) {
    yearElement.textContent = new Date().getFullYear();
  }
});
