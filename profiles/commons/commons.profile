<?php
/**
 * @file
 * Enables modules and site configuration for a Commons site installation.
 */

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function commons_form_install_configure_form_alter(&$form, $form_state) {
  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];

  $form['admin_account']['field_name_first'] = array(
    '#type' => 'textfield',
    '#title' => 'First name',
    '#weight' => -10,
  );

  $form['admin_account']['field_name_last'] = array(
    '#type' => 'textfield',
    '#title' => 'Last name',
    '#weight' => -9,
  );
    // Acquia features
  $form['server_settings']['acquia_description'] = array(
    '#type' => 'fieldset',
    '#title' => st('Acquia'),
    '#description' => st('The !an can supplement the functionality of Commons by providing enhanced site search (faceted search, content recommendations, content biasing, multi-site search, and others using the Apache Solr service), spam protection (using the Mollom service), and more.  A free 30-day trial is available.', array('!an' => l(t('Acquia Network'), 'http://acquia.com/products-services/acquia-network', array('attributes' => array('target' => '_blank'))))),
  );
  $form['server_settings']['enable_acquia_connector'] = array(
    '#type' => 'checkbox',
    '#title' => 'Use Acquia Network Connector',
    '#default_value' => 1,
    '#weight' => -10,
    '#return_value' => 1,
  );
  $form['server_settings']['acquia_connector_modules'] = array(
    '#type' => 'checkboxes',
    '#title' => 'Acquia Network Connector Modules',
    '#options' => array(
      'acquia_agent' => 'Acquia Agent',
      'acquia_search' => 'Acquia Search',
      'acquia_spi' => 'Acquia SPI',
    ),
    '#default_value' => array(
      'acquia_agent',
      'acquia_spi',
    ),
    '#weight' => -9,
    '#states' => array(
      'visible' => array(
        ':input[name="enable_acquia_connector"]' => array('checked' => TRUE),
      ),
    ),
  );

  $form['#submit'][] = 'commons_admin_save_fullname';
  $form['#submit'][] = 'commons_check_acquia_connector';
}


/**
 * Implements hook_update_projects_alter().
 */
function commons_update_projects_alter(&$projects) {
  // Enable update status for the Commons profile.
  $modules = system_rebuild_module_data();
  // The module object is shared in the request, so we need to clone it here.
  $commons = clone $modules['commons'];
  $commons->info['hidden'] = FALSE;
  _update_process_info_list($projects, array('commons' => $commons), 'module', TRUE);
}

/**
 * Implements hook_install_tasks().
 *
 * Allows the user to set a welcome message for anonymous users
 */
function commons_install_tasks() {

  $demo_content = variable_get('commons_install_demo_content', FALSE);
  $acquia_connector = variable_get('commons_install_acquia_connector', FALSE);

  return array(
    'commons_acquia_connector_enable' => array(
      'display' => FALSE,
      'type' => '',
      'run' => $acquia_connector ? INSTALL_TASK_RUN_IF_NOT_COMPLETED : INSTALL_TASK_SKIP,
    ),
    'commons_anonymous_message_homepage' => array(
      'display_name' => st('Enter Homepage welcome text'),
      'display' => TRUE,
      'type' => 'form',
      'function' => 'commons_anonymous_welcome_text_form'
    ),
    'commons_revert_features' => array(
      'display' => FALSE,
    ),
    'commons_demo_content' => array(
      'display' => FALSE,
      'type' => '',
      'run' => $demo_content ? INSTALL_TASK_RUN_IF_NOT_COMPLETED : INSTALL_TASK_SKIP,
    ),
    'commons_create_first_group' => array(
      'display_name' => st('Create the first group'),
      'display' => TRUE,
      'type' => 'form',
    ),
  );
}

/**
 * Let the admin user create the first group as part of the installation process
 */
function commons_create_first_group() {
  $form['commons_first_group_explanation'] = array(
    '#markup' => '<h2>' . st('Create the first group in your new community.') . '</h2>' . st("Commons uses groups to collect community members and content related to a particular interest, working goal or geographic area."),
    '#weight' => -1,
  );

  $form['commons_fist_group_example'] = array(
    '#markup' => theme('image', array('path' => 'profiles/commons/images/commons_group_description_sample.png', 'alt' => 'Group description page example', 'alt' => 'Group description example')),
    '#weight' => 0,
  );

  $form['commons_first_group_title'] = array(
    '#type' => 'textfield',
    '#title' => st("Group name"),
    '#description' => st('For example: "Boston food lovers" or "Engineering team."'),
    '#required' => TRUE,
    '#default_value' => st('Engineering team'),
  );

  $form['commons_first_group_body'] = array(
    '#type' => 'textarea',
    '#title' => st('Group description'),
    '#description' => st("This text will appear on the group's homepage and helps new contirbutors to become familiar with the purpose of the group. You can always change this text or add another group later."),
    '#required' => TRUE,
    '#default_value' => st('The online home for our Engineering team'),
  );

  $form['commons_first_group_submit'] = array(
    '#type'  => 'submit',
    '#value' => st('Save and continue')
  );

  return $form;
}

/**
 * Save the first group form
 *
 * @see commons_create_first_group().
 */
function commons_create_first_group_submit($form_id, &$form_state) {
  $values = $form_state['values'];

  $first_group = new stdClass();
  $first_group->type = 'group';
  node_object_prepare($first_group);

  $first_group->title = $values['commons_first_group_title'];
  $first_group->body[LANGUAGE_NONE][0]['value'] = $values['commons_first_group_body'];
  $first_group->uid = 1;
  $first_group->language = LANGUAGE_NONE;
  $first_group->status = 1;
  node_save($first_group);
}

/*
 * Revert Features after the installation.
 */
function commons_revert_features() {
  // These features must be twice in a row in order to
  // fully revert.
  $i = 0;
  while ($i < 2 ) {
   // Revert Features components to ensure that they are in their default states.
    $revert = array(
      'commons_groups' => array('field_instance'),
      'commons_wikis' => array('og_features_permission'),
    );
    features_revert($revert);
    $i++;
  }
}

/**
 * Save the full name of the first user.
 */
function commons_admin_save_fullname($form_id, &$form_state) {
  $values = $form_state['values'];
    if (!empty($values['field_name_first']) || !empty($values['field_name_last'])) {
    $account = user_load(1);
    $account->field_name_first[LANGUAGE_NONE][0]['value'] = $values['field_name_first'];
    $account->field_name_last[LANGUAGE_NONE][0]['value'] = $values['field_name_last'];
    user_save($account);
  }
}

/**
 * Check if the Acquia Connector box was selected.
 */
function commons_check_acquia_connector($form_id, &$form_state) {
  $values = $form_state['values'];
  if (isset($values['enable_acquia_connector']) && $values['enable_acquia_connector'] == 1) {
    $options = $values['acquia_connector_modules'];
    variable_set('commons_install_acquia_connector', TRUE);
    variable_set('commons_install_acquia_modules', array_keys($options));
  }
}

/**
 * Configuration form to set welcome text for the anonymous site homepage.
 */
function commons_anonymous_welcome_text_form() {
  $form['commons_anonymous_welcome_explanation'] = array(
    '#markup' => '<h2>' . st('Homepage welcome text') . '</h2>' . st("Below, enter text that will be shown on your community's homeage to help new visitors understand what your community is about and why they should join. The image below shows an example of how this text will appear. You can always change this text later."),
    '#weight' => -1,
  );
  $form['commons_anonymous_welcome_example'] = array(
    '#markup' => theme('image', array('path' => 'profiles/commons/images/commons_homepage_text_example.png', 'alt' => 'Home page example', 'alt' => 'Home page example')),
    '#weight' => 0,
  );

  $form['commons_anonymous_welcome_title'] = array(
    '#type' => 'textfield',
    '#title' => st('Welcome headline'),
    '#description' => st('A short description of the community that visitors can understand at a glance.'),
    '#required' => TRUE,
    '#default_value' => st('Welcome to our community'),
  );

  $form['commons_anonymous_welcome_body'] = array(
    '#type' => 'textarea',
    '#title' => st('Welcome body text'),
    '#description' => st('Enter a couple of sentences elborating about your community.'),
    '#required' => TRUE,
    '#default_value' => st('Share your thoughts, find answers to your questions.'),
  );

  $form['commons_install_demo_content'] = array(
    '#type' => 'checkbox',
    '#title' => st('Install demo content'),
    '#description' => st('Install Commons with example content so that you can get a sense of what your site will look like once it becomes more active.'),
    '#default_value' => TRUE
  );

  $form['commons_anonymous_welcome_submit'] = array(
    '#type'  => 'submit',
    '#value' => st('Save and continue')
  );

  return $form;
}

/**
 * Save the configuration form for set welcome text for anonymous users
 * @see commons_anonymous_welcome_text_form()
 */
function commons_anonymous_welcome_text_form_submit($form_id, &$form_state) {
  variable_set('commons_anonymous_welcome_title', $form_state['values']['commons_anonymous_welcome_title']);
  variable_set('commons_anonymous_welcome_body', $form_state['values']['commons_anonymous_welcome_body']);
  variable_set('commons_install_demo_content', $form_state['values']['commons_install_demo_content']);
}

/**
 * This function generate a demo content
 */
function commons_demo_content() {

  // Reset the Flag cache.
  flag_get_flags(NULL, NULL, NULL, TRUE);

  // Create demo Users
  $demo_users = array(
    'Lou White' => 'Lou White',
    'George Foreman' => 'George Foreman',
    'Cesar Ramirez' => 'Cesar Ramirez',
    'Elinor Dashwood' => 'Elinor Dashwood',
    'Matt Edmunds' => 'Matt Edmunds',
  );

  foreach ($demo_users as $name) {
    list($first_name, $last_name)  = explode(" ", $name);
    $normalize_name = drupal_strtolower(str_replace(' ','_', $name));
    $password = user_password(8);


    $fields = array(
      'name' => $name,
      'mail' => "{$normalize_name}@example.com",
      'pass' => $password,
      'status' => 1,
      'init' => "{$normalize_name}@example.com",
      'roles' => array(
        DRUPAL_AUTHENTICATED_RID => 'authenticated user'
      ),
    );

    $fields['field_name_first'][LANGUAGE_NONE][0]['value'] = $first_name;
    $fields['field_name_last'][LANGUAGE_NONE][0]['value'] = $last_name;


    $demo_users[$name] = user_save('', $fields);
  }

  // Demo Content.

  // Group: Boston
  $boston_group = new stdClass();
  $boston_group->type = 'group';
  node_object_prepare($boston_group);

  $boston_group->title = 'Boston';
  $boston_group->body[LANGUAGE_NONE][0]['value'] = commons_veggie_ipsum();
  $boston_group->uid = $demo_users['Lou White']->uid;
  $boston_group->language = LANGUAGE_NONE;
  $boston_group->created = time() - 604800;
  $boston_group->status = 1;
  node_save($boston_group);

  // Group: New York City
  $nyc_group = new stdClass();
  $nyc_group->type = 'group';
  node_object_prepare($nyc_group);

  $nyc_group->title = 'New York City';
  $nyc_group->body[LANGUAGE_NONE][0]['value'] = commons_veggie_ipsum();
  $nyc_group->uid = $demo_users['Lou White']->uid;
  $nyc_group->language = LANGUAGE_NONE;
  $nyc_group->status = 1;
  // Make the group 1 week old:
  $nyc_group->created = time() - 604800;
  node_save($nyc_group);


  // Post: Best brunch places in Cambridge
  $post = new stdClass();
  $post->type = 'post';
  node_object_prepare($post);

  $post->title = 'Best brunch places in Cambridge';
  $post->uid = $demo_users['George Foreman']->uid;
  $post->language = LANGUAGE_NONE;
  // 1:30 ago.
  $post->created = time() - 5400;
  $post->body[LANGUAGE_NONE][0]['value'] = "My aunt and I have been trying a lot of brunch places in Cambridge. Here's our favorites: <ul><li>North Street Grille for their breads
<li>Mixtura for the souffles
<li>The Neighborhood Restaurant for the vast quantities of food
<li>City Girl Cafe for the ambiance <li>Bom Cafe for granola";
  $post->body[LANGUAGE_NONE][0]['format'] = filter_default_format();

  $post->og_group_ref[LANGUAGE_NONE][0]['target_id'] = $boston_group->nid;
  $post->field_radioactivity[LANGUAGE_NONE][0]['radioactivity_energy'] = 8;

  $terms = array(
    'brunch',
    'Cambridge',
    'dining out'
  );

  foreach ($terms as $term) {
    $post->field_topics[LANGUAGE_NONE][]['tid'] = commons_create_topic($term);
  }

  node_save($post);


  // Wiki: How to create a veggie burger
  $wiki = new stdClass();
  $wiki->type = 'wiki';
  node_object_prepare($wiki);
  $group->created = time() - 604800;
  $wiki->title = 'How to create a veggie burger';
  $wiki->uid = $demo_users['Matt Edmunds']->uid;
  $wiki->language = LANGUAGE_NONE;
  $wiki->body[LANGUAGE_NONE][0]['value'] = "Celtuce quandong gumbo coriander avocado yarrow broccoli rabe parsnip nori mung bean watercress taro pea sprouts cress. Bush tomato water spinach radish green bean okra spinach garlic cress. Cucumber squash tigernut swiss chard celery cabbage beet greens nori groundnut grape melon seakale. Earthnut pea kakadu plum chicory potato plantain fennel gumbo chickweed gourd cauliflower wakame green bean epazote taro quandong. Celery turnip kombu lotus root lettuce sierra leone bologi kale cauliflower gumbo parsnip taro welsh onion melon asparagus green bean beet greens black-eyed pea jícama. Kohlrabi lentil turnip greens plantain bush tomato leek arugula courgette amaranth yarrow.";
  $wiki->body[LANGUAGE_NONE][0]['format'] = filter_default_format();

  $wiki->og_group_ref[LANGUAGE_NONE][0]['target_id'] = $boston_group->nid;
  $wiki->field_radioactivity[LANGUAGE_NONE][0]['radioactivity_energy'] = 8;

  $terms = array(
    'vegetarian',
    'casual',
    'meal',
    'recipe'
  );

  foreach ($terms as $term) {
    $wiki->field_topics[LANGUAGE_NONE][]['tid'] = commons_create_topic($term);
  }

  node_save($wiki);

  // Event: Ribfest Boston 2012
  $event = new stdClass();
  $event->type = 'event';
  node_object_prepare($event);

  $event->title = 'Ribfest Boston 2012';
  $event->uid = $demo_users['Elinor Dashwood']->uid;
  $event->language = LANGUAGE_NONE;
  $event->body[LANGUAGE_NONE][0]['value'] = "<strong>What ignited in 1999 as a community block party has exploded into one of Boston's most anticipated street festivals.</strong> Averaging 50,000 pounds of ribs and BBQ from more than 30 restaurants, Ribfest Boston 2013 is expected to draw more than 50,000 people. As a nationally recognized music festival, we host a hot blend of Indie, pop, Indie Roots, rock and alt country for one of the most unique band lineups in the city. Families can spend the whole weekend in Kids Square to enjoy live entertainment, inflatables, games and more.";
  $event->body[LANGUAGE_NONE][0]['format'] = filter_default_format();
  $event->og_group_ref[LANGUAGE_NONE][0]['target_id'] = $boston_group->nid;
  $terms = array(
    'bbq',
    'music',
    'festival'
  );

  foreach ($terms as $term) {
    $event->field_topics[LANGUAGE_NONE][]['tid'] = commons_create_topic($term);
  }

  $event->field_date[LANGUAGE_NONE][0]['value'] = '2014-01-12 10:00:00';
  $event->field_date[LANGUAGE_NONE][0]['value2'] = '2014-01-13 13:00:00';

  $event->field_address[LANGUAGE_NONE][0]['thoroughfare'] = '25 Corporate Drive';
  $event->field_address[LANGUAGE_NONE][0]['premise'] = '4th floor';
  $event->field_address[LANGUAGE_NONE][0]['postal_code'] = '01803';
  $event->field_address[LANGUAGE_NONE][0]['country'] = 'US';
  $event->field_address[LANGUAGE_NONE][0]['location'] = 'Waterfront';
  $event->field_address[LANGUAGE_NONE][0]['administrative_area']  = 'MA';
  $event->field_address[LANGUAGE_NONE][0]['locality'] = 'Boston';
  $event->og_group_ref[LANGUAGE_NONE][0]['target_id'] = $boston_group->nid;
  node_save($event);


  // Delete the demo content variable
  variable_del('commons_install_demo_content');
}

/**
  * Generate some filler content.
 */
function commons_veggie_ipsum() {
  $content = "Veggies sunt bona vobis, proinde vos postulo esse magis spinach kale scallion lettuce cucumber black-eyed pea onion.

Bamboo shoot green bean wattle seed okra kakadu plum peanut ricebean celtuce. Azuki bean desert raisin bush tomato turnip peanut sweet pepper courgette horseradish. Garlic kombu beet greens celery courgette carrot mung bean.";
  return $content;
}

/**
 * This function create a taxonomy topic, is used for create a demo content
 * for a new instalations of Drupal Commons
 *
 * @see commons_demo_content().
 */
function commons_create_topic($topic_name = '') {
  $term = new stdClass();
  $term->name = $topic_name;
  $term->vid = 1;
  // Pathauto aliasing can cause a menu_rebuild(), causing the request to
  // exceeed the max execution time. Specify a manual alias instead.
  // http://drupal.org/node/1867172.
  $term->path['pathauto'] = FALSE;
  taxonomy_term_save($term);
  $path = array(
    'source' => 'taxonomy/term/' . $term->tid,
    'alias' => 'topics/' . drupal_html_class($topic_name),
  );
  path_save($path);
  return $term->tid;
}

/**
 * Enable Acquia Connector module if selected on site configuration step.
 */
function commons_acquia_connector_enable() {
  $modules = variable_get('commons_install_acquia_modules', array());
  if (!empty($modules)) {
    module_enable($modules, TRUE);
  }
}
