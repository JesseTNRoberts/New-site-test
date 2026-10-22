---
layout: single
title: "Learn"
permalink: /learn/
author_profile: true
excerpt: "Interactive tools and demos for learning machine learning and deep learning."
---

Hands-on tools I've built for my courses. Everything runs in the browser, with nothing to install.

{% assign tc = site.data.torch_canvas %}
<section class="learn-feature">
  <p class="learn-feature__eyebrow">Tool · {{ tc.tool.tagline }}</p>
  <h2 class="learn-feature__title"><a href="{{ tc.tool.url }}">{{ tc.tool.title }}</a></h2>
  <p>{{ tc.tool.description }}</p>
  <p><a class="btn btn--primary" href="{{ tc.tool.url }}">Open {{ tc.tool.title }}</a></p>

  {% if tc.models.size > 0 %}
  <h3 class="learn-feature__subtitle">Start from a model</h3>
  <ul class="learn-list">
    {% for m in tc.models %}
    <li class="learn-card">
      <a class="learn-card__title" href="{{ tc.tool.url }}?open={{ m.id | url_encode }}">{{ m.title }}</a>
      {% if m.description %}<p class="learn-card__desc">{{ m.description }}</p>{% endif %}
      {% include learn-tags.html item=m %}
    </li>
    {% endfor %}
  </ul>
  {% endif %}
</section>

## Interactive demos

<ul class="learn-list">
  {% for d in site.data.demos %}
  <li class="learn-card">
    <a class="learn-card__title" href="{{ d.url | relative_url }}">{{ d.title }}</a>
    {% if d.description %}<p class="learn-card__desc">{{ d.description }}</p>{% endif %}
    {% include learn-tags.html item=d %}
  </li>
  {% endfor %}
</ul>

Course pages, with slides, are under [Teaching]({{ '/teaching/' | relative_url }}).
