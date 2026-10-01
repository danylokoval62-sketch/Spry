/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        display: ["Georgia", "serif"],
        sans: ["Avenir Next", "Helvetica Neue", "sans-serif"],
      },
      colors: {
        ink: "#20231f",
        paper: "#f4f0e8",
        moss: "#45624b",
        coral: "#d8785f",
        line: "#d8d0c2",
      },
    },
  },
  plugins: [],
};
