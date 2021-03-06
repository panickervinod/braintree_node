Braintree = require("../../../lib/braintree")
require("../../spec_helper")
Subscription = Braintree.Subscription

describe "SubscriptionSearch", ->
  describe "search", ->
    it "returns search results", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id
          textCriteria =
            id: subscriptionParams.id
            transactionId: response.subscription.transactions[0].id

          multipleValueCriteria =
            inTrialPeriod: false
            status: Subscription.Status.Active
            merchantAccountId: 'sandbox_credit_card'
            ids: subscriptionParams.id

          multipleValueOrTextCriteria =
            planId: specHelper.plans.trialless.id

          planPrice = Number(specHelper.plans.trialless.price)
          today = new Date()
          yesterday = new Date(today.getTime() - 24*60*60*1000)
          tomorrow = new Date(today.getTime() + 24*60*60*1000)
          billingCyclesRemaining = Number(response.subscription.numberOfBillingCycles) - 1

          rangeCriteria =
            price:
              min: planPrice - 1
              max: planPrice + 1
            billingCyclesRemaining:
              min: billingCyclesRemaining
              max: billingCyclesRemaining
            nextBillingDate:
              min: today
            createdAt:
              min: yesterday
              max: tomorrow

          search = (search) ->
            for criteria, value of textCriteria
              search[criteria]().is(value)

            for criteria, value of multipleValueCriteria
              search[criteria]().in(value)

            for criteria, value of multipleValueOrTextCriteria
              search[criteria]().startsWith(value)

            for criteria, range of rangeCriteria
              for operator, value of range
                search[criteria]()[operator](value)

          specHelper.defaultGateway.subscription.search search, (err, response) ->
            assert.isTrue(response.success)
            assert.equal(response.length(), 1)

            response.first (err, subscription) ->
              assert.isObject(subscription)
              assert.equal(subscription.id, subscriptionId)
              assert.isNull(err)

              done()

    it "does not return search results for out of range created_at parameters", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id
          textCriteria =
            id: subscriptionParams.id
            transactionId: response.subscription.transactions[0].id

          multipleValueCriteria =
            inTrialPeriod: false
            status: Subscription.Status.Active
            merchantAccountId: 'sandbox_credit_card'
            ids: subscriptionParams.id

          multipleValueOrTextCriteria =
            planId: specHelper.plans.trialless.id

          planPrice = Number(specHelper.plans.trialless.price)
          today = new Date()
          tomorrow = new Date(today.getTime() + 24*60*60*1000)
          dayAfterTomorrow = new Date(today.getTime() + 2*24*60*60*1000)
          billingCyclesRemaining = Number(response.subscription.numberOfBillingCycles) - 1

          rangeCriteria =
            price:
              min: planPrice - 1
              max: planPrice + 1
            billingCyclesRemaining:
              min: billingCyclesRemaining
              max: billingCyclesRemaining
            nextBillingDate:
              min: today
            createdAt:
              min: tomorrow
              max: dayAfterTomorrow

          search = (search) ->
            for criteria, value of textCriteria
              search[criteria]().is(value)

            for criteria, value of multipleValueCriteria
              search[criteria]().in(value)

            for criteria, value of multipleValueOrTextCriteria
              search[criteria]().startsWith(value)

            for criteria, range of rangeCriteria
              for operator, value of range
                search[criteria]()[operator](value)

          specHelper.defaultGateway.subscription.search search, (err, response) ->
            assert.isTrue(response.success)
            assert.equal(response.length(), 0)

            done()

    it "allows stream style interation of results", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id

          subscriptions = []

          search = specHelper.defaultGateway.subscription.search (search) ->
            search.id().is(subscriptionId)

          search.on 'data', (subscription) ->
            subscriptions.push(subscription)

          search.on 'end', ->
            assert.equal(subscriptions.length, 1)
            assert.equal(subscriptions[0].id, subscriptionId)

            done()

          search.resume()

    it "filters on valid merchant account ids", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id 

          multipleValueCriteria =
            merchantAccountId: 'sandbox_credit_card'
            ids: subscriptionParams.id

          search = (search) ->
            for criteria, value of multipleValueCriteria
              search[criteria]().in(value)

          specHelper.defaultGateway.subscription.search search, (err, response) ->
            assert.isTrue(response.success)
            assert.equal(1, response.length())
            done()

    it "filters on mixed valid and invalid merchant account ids", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id 

          multipleValueCriteria =
            merchantAccountId: ['sandbox_credit_card', 'invalid_merchant_id']
            ids: subscriptionParams.id

          search = (search) ->
            for criteria, value of multipleValueCriteria
              search[criteria]().in(value)

          specHelper.defaultGateway.subscription.search search, (err, response) ->
            assert.isTrue(response.success)
            assert.equal(1, response.length())
            done()

    it "filters on invalid merchant account ids", (done) ->
      customerParams =
        creditCard:
          number: '5105105105105100'
          expirationDate: '05/12'

      specHelper.defaultGateway.customer.create customerParams, (err, response) ->
        subscriptionParams =
          paymentMethodToken: response.customer.creditCards[0].token
          planId: specHelper.plans.trialless.id
          id: specHelper.randomId()

        specHelper.defaultGateway.subscription.create subscriptionParams, (err, response) ->
          subscriptionId = response.subscription.id 

          multipleValueCriteria =
            merchantAccountId: 'invalid_merchant_id'
            ids: subscriptionParams.id

          search = (search) ->
            for criteria, value of multipleValueCriteria
              search[criteria]().in(value)

          specHelper.defaultGateway.subscription.search search, (err, response) ->
            assert.isTrue(response.success)
            assert.equal(0, response.length())
            done()
