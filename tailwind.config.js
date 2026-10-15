const { slateDark } = require('@radix-ui/colors');
import { colors } from './theme/colors';
import { icons } from './theme/icons';
const defaultTheme = require('tailwindcss/defaultTheme');
const {
  iconsPlugin,
  getIconCollections,
} = require('@egoist/tailwindcss-icons');

const defaultSansFonts = [
  '-apple-system',
  'system-ui',
  'BlinkMacSystemFont',
  '"Segoe UI"',
  'Roboto',
  '"Helvetica Neue"',
  'Tahoma',
  'Arial',
  'sans-serif !important',
];

const tailwindConfig = {
  darkMode: 'class',
  content: [
    './enterprise/app/views/**/*.html.erb',
    './app/javascript/widget/**/*.vue',
    './app/javascript/v3/**/*.vue',
    './app/javascript/dashboard/**/*.vue',
    './app/javascript/portal/**/*.vue',
    './app/javascript/shared/**/*.vue',
    './app/javascript/survey/**/*.vue',
    './app/javascript/dashboard/components-next/**/*.vue',
    './app/javascript/dashboard/helper/**/*.js',
    './app/javascript/dashboard/composables/**/*.js',
    './app/javascript/dashboard/components-next/**/*.js',
    './app/javascript/dashboard/routes/dashboard/**/**/*.js',
    './app/views/**/*.html.erb',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: defaultSansFonts,
        // CUSTOMIZAÇÃO_SYNAPSEOS — Open Sans (Manual oficial) é a fonte primária.
        // Inter fica como fallback se Google Fonts não carregar.
        // 'font-inter' está em ~9 lugares do _woot.scss; reusamos a chave pra
        // não precisar refatorar e ativar Open Sans globalmente.
        inter: ['Inter', ...defaultSansFonts],
        interDisplay: ['"Space Grotesk"', 'InterDisplay', ...defaultSansFonts],
        synapse: ['Inter', ...defaultSansFonts],
        'synapse-display': ['"Space Grotesk"', 'Inter', ...defaultSansFonts],
        mono: ['"JetBrains Mono"', ...defaultTheme.fontFamily.mono],
      },
      boxShadow: {
        // CUSTOMIZAÇÃO_SYNAPSEOS — duas camadas, sutis mas visíveis em retina
        's-sm': 'var(--s-shadow-sm)',
        's-md': 'var(--s-shadow-md)',
        's-lg': 'var(--s-shadow-lg)',
      },
      ringColor: {
        // CUSTOMIZAÇÃO_SYNAPSEOS — focus ring padrão
        focus: 'rgb(var(--s-focus) / <alpha-value>)',
      },
      fontWeight: {
        420: '420',
        440: '440',
        460: '460',
        520: '520',
      },
      typography: {
        bubble: {
          css: {
            color: 'inherit',
            lineHeight: '1.6',
            fontSize: '14px',
            '*': {
              '&:first-child': {
                marginTop: '0',
              },
            },
            overflowWrap: 'anywhere',

            strong: {
              color: 'inherit',
              fontWeight: '700',
            },

            b: {
              color: 'inherit',
              fontWeight: '700',
            },

            h1: {
              color: 'inherit',
              fontWeight: '700',
              fontSize: '1.25rem',
              '&:first-child': {
                marginTop: '0',
              },
            },
            h2: {
              color: 'inherit',
              fontWeight: '700',
              fontSize: '1rem',
              '&:first-child': {
                marginTop: '0',
              },
            },
            h3: {
              color: 'inherit',
              fontWeight: '700',
              fontSize: '1rem',
              '&:first-child': {
                marginTop: '0',
              },
            },
            hr: {
              marginTop: '1.5em',
              marginBottom: '1.5em',
            },
            a: {
              color: 'inherit',
              textDecoration: 'underline',
            },
            ul: {
              paddingInlineStart: '0.625em',
            },
            ol: {
              paddingInlineStart: '0.625em',
            },
            'ul li': {
              margin: '0 0 0.5em 1em',
              listStyleType: 'disc',
              '[dir="rtl"] &': {
                margin: '0 1em 0.5em 0',
              },
            },
            'ol li': {
              margin: '0 0 0.5em 1em',
              listStyleType: 'decimal',
              '[dir="rtl"] &': {
                margin: '0 1em 0.5em 0',
              },
            },
            blockquote: {
              color: 'rgb(var(--slate-11))',
              borderLeft: `4px solid rgb(var(--black-alpha-1))`,
              paddingLeft: '1em',
              '[dir="rtl"] &': {
                borderLeft: 'none',
                paddingLeft: '0',
                borderRight: `4px solid rgb(var(--black-alpha-1))`,
                paddingRight: '1em',
              },
              '[dir="ltr"] &': {
                borderRight: 'none',
                paddingRight: '0',
              },
            },
            code: {
              backgroundColor: 'rgb(var(--alpha-3))',
              color: 'rgb(var(--slate-11))',
              padding: '0.2em 0.4em',
              borderRadius: '4px',
              fontSize: '0.95em',
              '&::before': {
                content: `none`,
              },
              '&::after': {
                content: `none`,
              },
            },
            pre: {
              backgroundColor: 'rgb(var(--alpha-3))',
              padding: '1em',
              borderRadius: '6px',
              overflowX: 'auto',
            },
            table: {
              width: '100%',
              borderCollapse: 'collapse',
            },
            th: {
              padding: '0.75em',
              color: 'inherit',
              border: `none`,
              textAlign: 'start',
              fontWeight: '600',
            },
            tr: {
              border: `none`,
            },
            td: {
              padding: '0.75em',
              border: `none`,
            },
            img: {
              maxWidth: '100%',
              height: 'auto',
              marginTop: 'unset',
              marginBottom: 'unset',
            },
          },
        },
      },
    },
    screens: {
      xs: '480px',
      sm: '640px',
      md: '768px',
      lg: '1024px',
      xl: '1280px',
      '2xl': '1536px',
      '3xl': '1900px',
    },
    fontSize: {
      ...defaultTheme.fontSize,
      xxs: '0.625rem',
    },
    colors: {
      transparent: 'transparent',
      white: '#fff',
      'modal-backdrop-light': 'rgba(0, 0, 0, 0.4)',
      'modal-backdrop-dark': 'rgba(0, 0, 0, 0.6)',
      current: 'currentColor',
      ...colors,
      body: slateDark.slate7,
    },
    keyframes: {
      ...defaultTheme.keyframes,
      wiggle: {
        '0%': { transform: 'translateX(0)' },
        '15%': { transform: 'translateX(0.375rem)' },
        '30%': { transform: 'translateX(-0.375rem)' },
        '45%': { transform: 'translateX(0.375rem)' },
        '60%': { transform: 'translateX(-0.375rem)' },
        '75%': { transform: 'translateX(0.375rem)' },
        '90%': { transform: 'translateX(-0.375rem)' },
        '100%': { transform: 'translateX(0)' },
      },
      'fade-in-up': {
        '0%': { opacity: 0, transform: 'translateY(0.5rem)' },
        '100%': { opacity: 1, transform: 'translateY(0)' },
      },
      'loader-pulse': {
        '0%': { opacity: 0.4 },
        '50%': { opacity: 1 },
        '100%': { opacity: 0.4 },
      },
      'card-select': {
        '0%, 100%': {
          transform: 'translateX(0)',
        },
        '50%': {
          transform: 'translateX(1px)',
        },
      },
      shake: {
        '0%, 100%': { transform: 'translateX(0)' },
        '25%': { transform: 'translateX(0.234375rem)' },
        '50%': { transform: 'translateX(-0.234375rem)' },
        '75%': { transform: 'translateX(0.234375rem)' },
      },
      // CUSTOMIZAÇÃO_SYNAPSEOS — movimento do design system Fykos.
      's-fade-in': {
        '0%': { opacity: 0 },
        '100%': { opacity: 1 },
      },
      's-scale-in': {
        '0%': { opacity: 0, transform: 'scale(0.97)' },
        '100%': { opacity: 1, transform: 'scale(1)' },
      },
      's-slide-in-right': {
        '0%': { opacity: 0, transform: 'translateX(1rem)' },
        '100%': { opacity: 1, transform: 'translateX(0)' },
      },
      's-skeleton': {
        '0%, 100%': { opacity: 1 },
        '50%': { opacity: 0.45 },
      },
      's-flash': {
        '0%': { boxShadow: '0 0 0 2px rgb(var(--s-flash-color, var(--s-accent)) / 0.9)' },
        '100%': { boxShadow: '0 0 0 2px rgb(var(--s-flash-color, var(--s-accent)) / 0)' },
      },
    },
    animation: {
      ...defaultTheme.animation,
      wiggle: 'wiggle 0.5s ease-in-out',
      'fade-in-up': 'fade-in-up 0.3s ease-out',
      'loader-pulse': 'loader-pulse 1.5s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      'card-select': 'card-select 0.25s ease-in-out',
      shake: 'shake 0.3s ease-in-out 0s 2',
      's-fade-in': 's-fade-in 200ms ease-out',
      's-scale-in': 's-scale-in 180ms ease-out',
      's-slide-in-right': 's-slide-in-right 220ms ease-out',
      's-skeleton': 's-skeleton 1.4s ease-in-out infinite',
      's-flash': 's-flash 1.2s ease-out',
    },
  },
  plugins: [
    // eslint-disable-next-line
    require('@tailwindcss/typography'),
    iconsPlugin({
      collections: {
        woot: { icons },
        ...getIconCollections([
          'lucide',
          'logos',
          'ri',
          'ph',
          'teenyicons',
          'fluent',
        ]),
      },
    }),
  ],
};

module.exports = tailwindConfig;
