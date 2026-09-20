import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { App } from './App';

describe('seed app', () => {
  it('renders a main landmark and readiness heading', () => {
    const markup = renderToStaticMarkup(<App />);
    expect(markup).toContain('<main>');
    expect(markup).toContain('<h1>Project ready</h1>');
  });
});
