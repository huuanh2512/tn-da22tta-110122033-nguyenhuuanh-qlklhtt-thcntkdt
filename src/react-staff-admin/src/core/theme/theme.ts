import { ThemeConfig } from 'antd';

export const getAntdTheme = (isDarkMode: boolean): ThemeConfig => ({
  token: {
    fontFamily: 'Inter, sans-serif',
    colorPrimary: '#FF5600', // finOrange accent
    colorBgLayout: isDarkMode ? '#121212' : '#F5F1EC', // Canvas
    colorBgContainer: isDarkMode ? '#1E1E1E' : '#FFFFFF', // Surface 1
    colorText: isDarkMode ? '#FFFFFF' : '#111111', // Ink
    colorTextDescription: isDarkMode ? '#9E9E9E' : '#626260', // Ink Muted
    colorBorder: isDarkMode ? '#2C2C2C' : '#D3CEC6', // Hairline
    borderRadius: 8, // md
  },
  components: {
    Button: {
      controlHeight: 40,
      paddingContentHorizontal: 18,
      borderRadius: 8,
      colorBgContainer: isDarkMode ? '#1E1E1E' : '#FFFFFF',
      colorBgContainerDisabled: isDarkMode ? '#2c2c2c' : '#f5f5f5',
    },
    Card: {
      borderRadiusLG: 16, // xl
      colorBorderSecondary: isDarkMode ? '#2C2C2C' : '#EDE9E3',
    },
    Table: {
      borderRadius: 12, // lg
      headerBg: isDarkMode ? '#2C2C2C' : '#EDE9E3',
    }
  }
});
