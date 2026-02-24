module.exports = {
  root: true,
  env: {
    node: true,
    es2022: true,
    jest: true,
  },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: './tsconfig.json',
  },
  plugins: ['@typescript-eslint', 'prettier'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'plugin:prettier/recommended',
  ],
  rules: {
    // Prettier integration
    'prettier/prettier': 'error',

    // Complexity/size: warn so CI and pre-commit pass; tighten to error incrementally (see CODE_QUALITY.md)
    complexity: ['warn', { max: 10 }],
    'max-depth': ['warn', { max: 3 }],
    'max-lines': ['warn', { max: 300, skipBlankLines: true, skipComments: true }],
    'max-lines-per-function': [
      'warn',
      { max: 50, skipBlankLines: true, skipComments: true },
    ],
    'max-params': ['warn', { max: 4 }],
    'max-statements': ['warn', { max: 20 }],

    // TypeScript: keep strict where easy to fix; warn on the rest until codebase is cleaned
    '@typescript-eslint/explicit-function-return-type': 'warn',
    '@typescript-eslint/no-unused-vars': [
      'error',
      { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
    ],
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-floating-promises': 'error',
    '@typescript-eslint/no-misused-promises': 'warn', // Express async handlers; add wrapper to promote to error
    '@typescript-eslint/await-thenable': 'error',
    '@typescript-eslint/require-await': 'error',
    '@typescript-eslint/no-unsafe-assignment': 'warn',
    '@typescript-eslint/no-unsafe-member-access': 'warn',
    '@typescript-eslint/no-unsafe-call': 'warn',
    '@typescript-eslint/no-unsafe-return': 'warn',

    // General best practices
    'no-console': ['warn', { allow: ['warn', 'error', 'info'] }],
    'no-return-await': 'error',
    'prefer-const': 'error',
    'no-var': 'error',
    eqeqeq: ['error', 'always'],
    curly: ['error', 'all'],
  },
  overrides: [
    {
      files: ['**/*.test.ts', 'src/tests/**/*.ts'],
      rules: {
        'max-lines-per-function': 'off',
        'max-lines': 'off',
        '@typescript-eslint/no-unsafe-assignment': 'off',
        '@typescript-eslint/no-unsafe-member-access': 'off',
        'no-console': 'off',
      },
    },
  ],
  ignorePatterns: ['dist', 'node_modules', '*.js', '*.cjs', 'coverage'],
};



