import Chart from "../../vendor/chart.min.js"

const ChartHook = {
  mounted() {
    this.chart = new Chart(this.el, {
      type: this.el.dataset.chartType || "doughnut",
      data: JSON.parse(this.el.dataset.chartData),
      options: JSON.parse(this.el.dataset.chartOptions || "{}")
    })
  },
  updated() {
    const data = JSON.parse(this.el.dataset.chartData)
    this.chart.data = data
    this.chart.update()
  },
  destroyed() {
    this.chart.destroy()
  }
}

export default ChartHook
