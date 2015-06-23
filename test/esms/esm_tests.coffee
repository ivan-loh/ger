esm_tests = (ESM) ->
  ns = "default"

  describe 'construction', ->
    describe '#initialize #exists #destroy', ->
      it 'should initialize namespace', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal false)
        .then( -> esm.initialize(namespace))
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal true)    

      it 'should sucessfully initialize namespace with default', ->
        #based on an error where default is a reserved name in postgres
        namespace = "default"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal false)
        .then( -> esm.initialize(namespace))
        .then( -> esm.exists(namespace))
        .then( (exist) -> exist.should.equal true)

      it 'should start with no events', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.initialize(namespace))
        .then( -> esm.count_events(namespace))
        .then( (count) -> 
          count.should.equal 0
        )
        
      it 'should not error out or remove events if re-initialized', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy()
        .then( -> esm.initialize(namespace))
        .then( -> esm.add_event(namespace, 'p','a','t'))
        .then( -> esm.count_events(namespace))
        .then( (count) -> count.should.equal 1)
        .then( -> esm.initialize(namespace))
        .then( -> esm.count_events(namespace))
        .then( (count) -> count.should.equal 1)

      it 'should create resources for ESM namespace', ->
        ns1 = "namespace1"
        ns2 = "namespace2"
        esm = new_esm(ESM) #pass knex as it might be needed
        bb.all([esm.destroy(ns1), esm.destroy(ns2)])
        .then( -> bb.all([esm.initialize(ns1), esm.initialize(ns2)]) )
        .then( ->
          bb.all([
            esm.add_event(ns1, 'p','a','t')
            esm.add_event(ns1, 'p1','a','t')
            
            esm.add_event(ns2, 'p2','a','t')
          ])
        )
        .then( ->
          bb.all([esm.count_events(ns1), esm.count_events(ns2) ])
        )
        .spread((c1,c2) ->
          c1.should.equal 2
          c2.should.equal 1
        )

      it 'should destroy should not break if resource does not exist', ->
        namespace = "namespace"
        esm = new_esm(ESM)
        esm.destroy(namespace)
        .then( -> esm.destroy(namespace))

  describe 'recommendation methods', ->

    describe '#thing_neighbourhood', ->
      it 'should return a list of similar things', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','view','t2', expires_at: tomorrow)
          ])
          .then( ->
            esm.thing_neighbourhood(ns, 't1', ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].should.equal 't2'
          )

    describe '#person_neighbourhood' , ->
      it 'should return a list of similar people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','buy','t1', expires_at: tomorrow)
            esm.add_event(ns,'p1','buy','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view', 'buy'])
          )
          .then( (people) ->
            people.length.should.equal 1
          )

      it 'should not return people who have no unexpired events (i.e. potential recommendations) or in actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p3','view','t1', expires_at: yesterday)
            esm.add_event(ns,'p4','view','t1')
            esm.add_event(ns,'p5','view','t1')
            esm.add_event(ns,'p5','likes','t2', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view','buy'])
          )
          .then( (people) ->
            people.length.should.equal 1
          )

      it 'should not return more people than limited', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p3','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p4','view','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view','buy'], {neighbourhood_size: 1})
          )
          .then( (people) ->
            people.length.should.equal 1
            esm.person_neighbourhood(ns, 'p1', ['view','buy'], {neighbourhood_size: 2})
          )
          .then( (people) ->
            people.length.should.equal 2
          )

      it 'should not return the given person', ->
        @timeout(360000)
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['view'])
          )
          .then( (people) ->
            people.length.should.equal 0
          )

      it 'should only return people related via given actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','view','t1', expires_at: tomorrow)
            esm.add_event(ns,'p2','buy','t1', expires_at: tomorrow)
          ])
          .then( ->
            esm.person_neighbourhood(ns, 'p1', ['buy'])
          )
          .then( (people) ->
            people.length.should.equal 0
          )

      it 'should find similar people across actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','a'),
            esm.add_event(ns, 'p1','view','b'),
            #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
            esm.add_event(ns, 'p2','view','a'),
            esm.add_event(ns, 'p2','view','b'),
            esm.add_event(ns, 'p2','buy','x', created_at: moment().subtract(2, 'days'), expires_at: tomorrow),

            esm.add_event(ns, 'p3','view','a'),
            esm.add_event(ns, 'p3','buy','l', created_at: moment().subtract(3, 'hours'), expires_at: tomorrow),
            esm.add_event(ns, 'p3','buy','m', created_at: moment().subtract(2, 'hours'), expires_at: tomorrow),
            esm.add_event(ns, 'p3','buy','n', created_at: moment().subtract(1, 'hours'), expires_at: tomorrow)
          ])
          .then(-> esm.person_neighbourhood(ns, 'p1', ['buy', 'view']))
          .then((people) ->
            people.length.should.equal 2
          )

      it 'should be able to set current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','view','a', created_at: moment().subtract(3, 'days')),
            esm.add_event(ns, 'p1','view','b', created_at: moment().subtract(1, 'days')),
            #p2 is closer to p1, but theie recommendation was 2 days ago. It should still be included
            esm.add_event(ns, 'p2','view','a', created_at: moment().subtract(3, 'days'), expires_at: tomorrow),

            esm.add_event(ns, 'p3','view','b', created_at: moment().subtract(3, 'days'), expires_at: tomorrow)
          ])
          .then(-> 
            esm.person_neighbourhood(ns, 'p1', ['view'])
          )
          .then((people) ->
            people.length.should.equal 2
            esm.person_neighbourhood(ns, 'p1', ['view'], current_datetime: moment().subtract(2, 'days'))
          )
          .then((people) ->
            people.length.should.equal 1
          )

    describe '#calculate_similarities_from_person', ->
      it 'more similar histories should be greater', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1')
            esm.add_event(ns,'p1','a','t2')

            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p2','a','t2')

            esm.add_event(ns,'p3','a','t1')
            esm.add_event(ns,'p3','a','t3')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],['a']))
          .then( (similarities) ->
            similarities['p3']['a'].should.be.lessThan(similarities['p2']['a'])
          )

      it 'should handle multiple actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1')
            esm.add_event(ns,'p1','b','t2')

            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p2','b','t2')

            esm.add_event(ns,'p3','a','t1')
            esm.add_event(ns,'p3','b','t3')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],['a','b']))
          .then( (similarities) ->
            similarities['p3']['b'].should.be.lessThan(similarities['p2']['b'])
            similarities['p3']['a'].should.be.equal(similarities['p2']['a'])
          )

      it 'should calculate the similarity between a person and a set of people for a list of actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1'),
            esm.add_event(ns,'p2','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.exist
          )

      it 'more should be able to set the current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: yesterday)

            esm.add_event(ns,'p2','a','t1', created_at: yesterday)

            esm.add_event(ns,'p3','a','t1')
          ])
          .then( -> 
            esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],['a'], current_datetime: yesterday)
          ) 
          .then( (similarities) ->
            similarities['p3']['a'].should.be.lessThan(similarities['p2']['a'])
            esm.calculate_similarities_from_person(ns, 'p1',['p2','p3'],['a'])
          )
          .then( (similarities) ->
            similarities['p3']['a'].should.equal(similarities['p2']['a'])
          )

      describe "recent events", ->
        it 'should have a higher impact on similarity', ->
          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','a','t1', created_at: new Date()),
              esm.add_event(ns,'p2','a','t1', created_at: moment().subtract(2, 'days'))
              esm.add_event(ns,'p3','a','t1', created_at: moment().subtract(6, 'days'))

            ])
            .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],['a'], recent_event_days: 5 ))
            .then( (similarities) ->
              similarities['p3']['a'].should.be.lessThan(similarities['p2']['a'])
            )

        it 'should be ale to set current_datetime', ->
          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','a','t1', created_at: new Date()),
              esm.add_event(ns,'p2','a','t1', created_at: moment().subtract(2, 'days'))
              esm.add_event(ns,'p3','a','t1', created_at: moment().subtract(6, 'days'))

            ])
            .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],['a'], recent_event_days: 5, current_datetime: moment().subtract(3, 'days')))
            .then( (similarities) ->
              similarities['p3']['a'].should.equal(similarities['p2']['a'])
            )

      it 'should have a same similarity if histories are inversed', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p2','a','t1', created_at: moment().subtract(10, 'days'))

            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(10, 'days')),
            esm.add_event(ns,'p3','a','t2', created_at: new Date())
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],['a'], { recent_event_days: 5 }))
          .then( (similarities) ->
            similarities['p3']['a'].should.equal similarities['p2']['a']
          )

      it 'should not be effected by having same events (through add_event)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1'),
            esm.add_event(ns,'p2','a','t1')
            esm.add_event(ns,'p3','a','t1')
            esm.add_event(ns,'p3','a','t1')
          ])
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.equal similarities['p3']['a']
          )

      it 'should not be effected by having same events (through bootstrap)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          rs = new Readable();
          rs.push('p1,a,t1,2013-01-01,\n');
          rs.push('p2,a,t1,2013-01-01,\n');
          rs.push('p3,a,t1,2013-01-01,\n');
          rs.push('p3,a,t1,2013-01-01,\n');
          rs.push(null);
          esm.bootstrap(ns, rs)
          .then( -> esm.calculate_similarities_from_person(ns, 'p1',['p2', 'p3'],['a']))
          .then( (similarities) ->
            similarities['p2']['a'].should.equal similarities['p3']['a']
          )

      it 'should not be effected by having bad names', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,"'p\n,1};","v'i\new","'a\n;"),
            esm.add_event(ns,"'p\n2};","v'i\new","'a\n;")
          ])
          .then(-> esm.calculate_similarities_from_person(ns, "'p\n,1};",["'p\n2};"], ["v'i\new"]))
          .then((similarities) ->
            similarities["'p\n2};"]["v'i\new"].should.be.greaterThan(0)
          )

    describe '#recently_actioned_things_by_people', ->

      # TODO multiple returned things 
      # it 'should return multiple things for multiple actions', ->
      #   init_esm(ESM, ns)
      #   .then (esm) ->
      #     bb.all([
      #       esm.add_event(ns,'p1','a1','t1', expires_at: tomorrow),
      #       esm.add_event(ns,'p1','a2','t1', expires_at: tomorrow)
      #     ])
      #     .then( -> esm.recently_actioned_things_by_people(ns, ['a1', 'a2'], ['p1']))
      #     .then( (people_things) ->
      #       people_things['p1']['a1'].length.should.equal 1
      #       people_things['p1']['a2'].length.should.equal 1
      #     )

      it 'should only return things created before current_datetime', ->
        a2daysago = moment().subtract(2, 'days')
        a3daysago = moment().subtract(3, 'days')
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: today, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', created_at: yesterday, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t3', created_at: a2daysago, expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t4', created_at: a3daysago, expires_at: tomorrow),
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'], ['p1']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 4
            esm.recently_actioned_things_by_people(ns, ['a'], ['p1'], current_datetime: yesterday)
          )
          .then( (people_things) ->
            people_things['p1'].length.should.equal 3
            esm.recently_actioned_things_by_people(ns, ['a'], ['p1'], current_datetime: a2daysago)
          )
          .then( (people_things) ->
            people_things['p1'].length.should.equal 2
          )


      it 'should return multiple things for multiple actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a1','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a2','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a1', 'a2'], ['p1']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 2
          )

      it 'should return things for multiple actions and multiple people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a1','t1', expires_at: tomorrow),
            esm.add_event(ns,'p2','a2','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a1', 'a2'] ,['p1', 'p2']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
            people_things['p1'][0].thing.should.equal 't1'
            people_things['p2'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't2'
          )

      it 'should return things for multiple people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p2','a','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'] ,['p1', 'p2']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
            people_things['p1'].length.should.equal 1
          )

      it 'should not return things without expiry date', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2')
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'], ['p1']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
          )

      it 'should not return expired things', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', expires_at: yesterday)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'], ['p1']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
          )


      it 'should return a list of things that people have actioned', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p2','a','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'], ['p1','p2']))
          .then( (people_things) ->
            people_things['p1'][0].thing.should.equal 't1'
            people_things['p1'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't2'
            people_things['p2'].length.should.equal 1
          )

      it 'should return the same item for different people', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t', expires_at: tomorrow), 
            esm.add_event(ns,'p2','a','t', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, ['a'],['p1','p2']))
          .then( (people_things) ->
            people_things['p1'][0].thing.should.equal 't'
            people_things['p1'].length.should.equal 1
            people_things['p2'][0].thing.should.equal 't'
            people_things['p2'].length.should.equal 1
          )

      it 'should be limited by related things limit', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t2', expires_at: tomorrow),
            esm.add_event(ns,'p2','a','t2', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, 'a',['p1','p2'], {related_things_limit: 1}))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
            people_things['p2'].length.should.equal 1
          )
      


      it 'should return the last_expires_at date', ->
        nextWeekdate = moment().add(7, 'days').millisecond(0)
        nextWeek = nextWeekdate.format()

        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: tomorrow),
            esm.add_event(ns,'p1','a','t1', expires_at: nextWeek)
            esm.add_event(ns,'p2','a','t1', expires_at: tomorrow)
          ])
          .then( -> esm.recently_actioned_things_by_people(ns, 'a', ['p1', 'p2']))
          .then( (people_things) ->
            people_things['p1'].length.should.equal 1
            people_things['p1'][0].last_expires_at.should.equal nextWeekdate.toDate().getTime()
            people_things['p2'].length.should.equal 1
            people_things['p2'][0].last_expires_at.should.equal tomorrow.toDate().getTime()
          )

      describe 'time_until_expiry', ->

        it 'should not return things that expire before the date passed', ->
          
          a1day = moment().add(1, 'days').format()
          a2days = moment().add(2, 'days').format()
          a3days = moment().add(3, 'days').format()

          init_esm(ESM, ns)
          .then (esm) ->
            bb.all([
              esm.add_event(ns,'p1','a','t1', expires_at: a3days),
              esm.add_event(ns,'p2','a','t2', expires_at: a1day)
            ])
            .then( -> esm.recently_actioned_things_by_people(ns, 'a',['p1','p2'], { time_until_expiry: 48*60*60}))
            .then( (people_things) ->
              people_things['p1'].length.should.equal 1
              people_things['p2'].length.should.equal 0
            )


    describe '#filter_things_by_previous_actions', ->
      it 'should remove things that a person has previously actioned', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].should.equal 't2'
          )

      it 'should filter things only for given actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','buy','t2')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view'])
          )
          .then( (things) ->
            things.length.should.equal 1
            things[0].should.equal 't2'
          )

      it 'should filter things for multiple actions', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','buy','t2')
          ])
          .then( ->
            esm.filter_things_by_previous_actions(ns, 'p1', ['t1','t2'], ['view', 'buy'])
          )
          .then( (things) ->
            things.length.should.equal 0
          )

  describe 'inserting data', ->
    describe '#add_events', ->
      it 'should add an events to the ESM', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_events([{namespace: ns, person: 'p', action: 'a', thing: 't'}])
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
          )

      it 'should add multiple events to the ESM', ->
        exp_date = (new Date()).toISOString()
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_events([
            {namespace: ns, person: 'p1', action: 'a', thing: 't1'}
            {namespace: ns, person: 'p1', action: 'a', thing: 't2', created_at: new Date().toISOString()}
            {namespace: ns, person: 'p1', action: 'a', thing: 't3', expires_at: exp_date}
          ])
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 3
            esm.find_events(ns, person: 'p1', action: 'a', thing: 't3')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
            event.expires_at.toISOString().should.equal exp_date
          )


    describe '#add_event', ->
      it 'should add an event to the ESM', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.should.not.equal null
          )

    describe '#count_events', ->
      it 'should return the number of events in the event store', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.count_events(ns)
          )
          .then( (count) ->
            count.should.equal 1
          )

    describe '#estimate_event_count', ->
      it 'should be a fast estimate of events', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','view','t3')
          ])
          .then( ->
            esm.pre_compact(ns)
          )
          .then( ->
            esm.estimate_event_count(ns)
          )
          .then( (count) ->
            count.should.equal 3
          )

    describe '#delete_events', ->
      it "should return 0 if no events are deleted", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.delete_events(ns, 'p','a','t')
          .then( (ret) ->
            ret.deleted.should.equal 0
          )

      it "should delete events from esm", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns, person: 'p1', action: 'view', thing: 't1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 1
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 2
          )

      it "should delete events from esm for person", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns, 'p1')
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 0
          )

      it "should delete events from esm for action", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns, action: 'view')
          )
          .then( (ret) ->
            ret.deleted.should.equal 2
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 1
          )

      it "should delete all events if no value is given", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            esm.delete_events(ns)
          )
          .then( (ret) ->
            ret.deleted.should.equal 3
            esm.count_events(ns)
          ).then( (count) ->
            count.should.equal 0
          )

    describe '#find_events', ->
      it 'should return the event', ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          )
          .then( (events) ->
            event = events[0]
            event.person.should.equal 'p'
            event.action.should.equal 'a'
            event.thing.should.equal 't'
          )

      it "should return null if no event matches", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.find_events(ns, person: 'p', action: 'a', thing: 't')
          .then( (events) ->
            events.length.should.equal 0
          )

      it "should find event with only one argument", ->
        init_esm(ESM, ns)
        .then (esm) ->
          esm.add_event(ns,'p','a','t')
          .then( ->
            bb.all([
              esm.find_events(ns, person: 'p')
              esm.find_events(ns, action: 'a')
              esm.find_events(ns, thing: 't')
            ])
          )
          .spread( (events1, events2, events3) ->
            e1 = events1[0]
            e2 = events2[0]
            e3 = events3[0]
            for event in [e1, e2, e3]
              event.person.should.equal 'p'
              event.action.should.equal 'a'
              event.thing.should.equal 't'
          )

      it "should return multiple events", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
          ])
          .then( ->
            bb.all([
              esm.find_events(ns, person: 'p1')
              esm.find_events(ns, person:'p1', action: 'view')
              esm.find_events(ns, person:'p1', action: 'view', thing: 't1')
              esm.find_events(ns, action: 'view')
              esm.find_events(ns, person: 'p1', thing:'t1')
            ])
          )
          .spread( (events1, events2, events3, events4, events5) ->
            events1.length.should.equal 3
            events2.length.should.equal 2
            events3.length.should.equal 1
            events4.length.should.equal 2
            events5.length.should.equal 2
          )

      it "should return events in created_at descending order (most recent first)", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns,'p1','a','t3', created_at: moment().subtract(10, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            events[0].thing.should.equal 't1'
            events[1].thing.should.equal 't2'
            events[2].thing.should.equal 't3'
          )

      it "should return only the most recent unique events", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: today),
            esm.add_event(ns,'p1','a','t1', created_at: yesterday)
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 1
            moment(events[0].created_at).format().should.equal today.format()
            events[0].thing.should.equal 't1'
          )

      it "should limit the returned events to size", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns,'p1','a','t3', created_at: moment().subtract(10, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1', size: 2)
          )
          .then( (events) ->
            events.length.should.equal 2
            events[0].thing.should.equal 't1'
            events[1].thing.should.equal 't2'
          )

      it "should return pagable events", ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns, 'p1','a','t1', created_at: new Date()),
            esm.add_event(ns, 'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns, 'p1','a','t3', created_at: moment().subtract(10, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1', size: 2, page: 1)
          )
          .then( (events) ->
            events.length.should.equal 1
            events[0].thing.should.equal 't3'
          )

      it 'should be able to take arrays', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','view','t1')
            esm.add_event(ns,'p1','view','t2')
            esm.add_event(ns,'p1','like','t1')
            esm.add_event(ns,'p2','view','t1')
          ])
          .then( ->
            bb.all([
              esm.find_events(ns, people: ['p1', 'p2'])
              esm.find_events(ns, person: 'p1', actions: ['view', 'like'])
              esm.find_events(ns, person: 'p1', action: 'view', things: ['t1','t2'])
            ])
          )
          .spread( (events1, events2, events3) ->
            events1.length.should.equal 4
            events2.length.should.equal 3
            events3.length.should.equal 2
          )

      it 'should be able to select current_datetime', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', created_at: new Date()),
            esm.add_event(ns,'p1','a','t2', created_at: moment().subtract(2, 'days'))
            esm.add_event(ns,'p1','a','t3', created_at: moment().subtract(6, 'days'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            esm.find_events(ns, person: 'p1', current_datetime: moment().subtract(1, 'days'))
          )
          .then( (events) ->
            events.length.should.equal 2
            esm.find_events(ns, person: 'p1', current_datetime: moment().subtract(3, 'days'))
          )
          .then( (events) ->
            events.length.should.equal 1
          )

      it 'should be able to select time_until_expiry', ->
        init_esm(ESM, ns)
        .then (esm) ->
          bb.all([
            esm.add_event(ns,'p1','a','t1', expires_at: today),
            esm.add_event(ns,'p1','a','t2', expires_at: moment(today).add(10, 'minutes'))
            esm.add_event(ns,'p1','a','t3', expires_at: moment(today).add(100, 'minutes'))
          ])
          .then( ->
            esm.find_events(ns, person: 'p1')
          )
          .then( (events) ->
            events.length.should.equal 3
            esm.find_events(ns, person: 'p1', time_until_expiry: 60)
          )
          .then( (events) ->
            events.length.should.equal 2
            esm.find_events(ns, person: 'p1', time_until_expiry: 630)
          )
          .then( (events) ->
            events.length.should.equal 1
          )

    describe '#bootstrap', ->
      it 'should add a stream of events (person,action,thing,created_at,expires_at)', ->
        init_esm(ESM, ns)
        .then (esm) ->
          rs = new Readable();
          rs.push('person,action,thing,2014-01-01,\n');
          rs.push('person,action,thing1,2014-01-01,\n');
          rs.push('person,action,thing2,2014-01-01,\n');
          rs.push(null);

          esm.bootstrap(ns, rs)
          .then( (returned_count) -> bb.all([returned_count, esm.count_events(ns)]))
          .spread( (returned_count, count) ->
            count.should.equal 3
            returned_count.should.equal 3
          )

      it 'should select the most recent created_at date for any duplicate events', ->
        init_esm(ESM, ns)
        .then (esm) ->
          rs = new Readable();
          rs.push('person,action,thing,2013-01-02,\n');
          rs.push('person,action,thing,2014-01-02,\n');
          rs.push(null);
          esm.bootstrap(ns, rs)
          .then( ->
            esm.pre_compact(ns)
          )
          .then( ->
            esm.compact_people(ns, 1, ['action'])
          )
          .then( -> esm.count_events(ns))
          .then( (count) ->
            count.should.equal 1
            esm.find_events(ns, person: 'person', action: 'action', thing: 'thing')
          )
          .then( (events) ->
            event = events[0]
            expected_created_at = new Date('2014-01-01')
            event.created_at.getFullYear().should.equal expected_created_at.getFullYear()
          )

      it 'should load a set of events from a file into the database', ->
        init_esm(ESM, ns)
        .then (esm) ->
          fileStream = fs.createReadStream(path.resolve('./test/test_events.csv'))
          esm.bootstrap(ns, fileStream)
          .then( (count) -> count.should.equal 3; esm.count_events(ns))
          .then( (count) -> count.should.equal 3)


for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)



