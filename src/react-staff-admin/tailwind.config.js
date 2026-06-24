/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  darkMode: 'class', // Hỗ trợ chuyển đổi Light/Dark mode qua class 'dark' ở thẻ html
  theme: {
    extend: {
      colors: {
        canvas: {
          DEFAULT: '#F5F1EC',
          dark: '#121212',
        },
        surface: {
          1: '#FFFFFF',
          2: '#EDE9E3',
          dark1: '#1E1E1E',
          dark2: '#2C2C2C',
        },
        ink: {
          DEFAULT: '#111111',
          muted: '#626260',
          subtle: '#7B7B78',
          tertiary: '#9C9FA5',
          darkMuted: '#9E9E9E',
          darkSubtle: '#BDBDBD',
        },
        brand: {
          orange: '#FF5600',
        },
        semantic: {
          success: '#1E8A44',
          successDark: '#30D158',
          error: '#D93025',
          warning: '#F59E0B',
          border: '#D3CEC6',
          borderDark: '#2C2C2C',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      borderRadius: {
        'xs': '4px',
        'sm': '6px',
        'md': '8px',
        'lg': '12px',
        'xl': '16px',
        'xxl': '24px',
      },
      spacing: {
        'button-v': '10px',
        'button-h': '18px',
        'card-p': '24px',
      }
    },
  },
  plugins: [],
}
