import type { Config } from 'tailwindcss';
const config: Config = { content: ['./app/**/*.{js,ts,jsx,tsx,mdx}', './components/**/*.{js,ts,jsx,tsx,mdx}'], theme: { extend: { colors: { ink: '#171717', coral: '#ff6848', cream: '#fffaf5' }, boxShadow: { soft: '0 12px 40px rgba(27, 24, 21, .07)' } } }, plugins: [] };
export default config;
