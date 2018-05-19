require 'themis/finals/attack/result'
require './lib/utils/event_emitter'

module Themis
  module Finals
    module Controllers
      module Attack
        def self.get_recent
          attacks = []
          ::Themis::Finals::Models::Team.all.each do |team|
            attack = ::Themis::Finals::Models::Attack.last(
              team_id: team.id,
              considered: true
            )

            unless attack.nil?
              attacks << attack
            end
          end

          attacks
        end

        def self.consider_attack(attack)
          attack.considered = true
          attack.save
        end

        def self.internal_process(attempt, team, data)
          unless data.respond_to?('match')
            r = ::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT
            attempt.response = r
            attempt.save
            return r
          end

          match_ = data.match(/^[\da-f]{32}=$/)
          if match_.nil?
            r = ::Themis::Finals::Attack::Result::ERR_INVALID_FORMAT
            attempt.response = r
            attempt.save
            return r
          end

          flag = ::Themis::Finals::Models::Flag.exclude(
            pushed_at: nil
          ).where(
            flag: match_[0]
          ).first

          if flag.nil?
            r = ::Themis::Finals::Attack::Result::ERR_FLAG_NOT_FOUND
            attempt.response = r
            attempt.save
            return r
          end

          if flag.team_id == team.id
            r = ::Themis::Finals::Attack::Result::ERR_FLAG_YOURS
            attempt.response = r
            attempt.save
            return r
          end

          team_service_push_state = ::Themis::Finals::Models::TeamServicePushState.first(
            team_id: team.id,
            service_id: flag.service_id
          )
          team_service_push_ok = \
            !team_service_push_state.nil? && team_service_push_state.state == ::Themis::Finals::Constants::TeamServiceState::UP

          team_service_pull_state = ::Themis::Finals::Models::TeamServicePullState.first(
            team_id: team.id,
            service_id: flag.service_id
          )
          team_service_pull_ok = \
            !team_service_pull_state.nil? && team_service_pull_state.state == ::Themis::Finals::Constants::TeamServiceState::UP

          unless team_service_push_ok && team_service_pull_ok
            r = ::Themis::Finals::Attack::Result::ERR_SERVICE_NOT_UP
            attempt.response = r
            attempt.save
            return r
          end

          if flag.expired_at.to_datetime < ::DateTime.now
            r = ::Themis::Finals::Attack::Result::ERR_FLAG_EXPIRED
            attempt.response = r
            attempt.save
            return r
          end

          r = nil
          begin
            ::Themis::Finals::Models::DB.transaction do
              ::Themis::Finals::Models::Attack.create(
                occured_at: ::DateTime.now,
                considered: false,
                team_id: team.id,
                flag_id: flag.id
              )
              r = ::Themis::Finals::Attack::Result::SUCCESS_FLAG_ACCEPTED

              ::Themis::Finals::Utils::EventEmitter.emit_log(
                4,
                attack_team_id: team.id,
                victim_team_id: flag.team_id,
                service_id: flag.service_id
              )
            end
          rescue ::Sequel::UniqueConstraintViolation => e
            r = ::Themis::Finals::Attack::Result::ERR_FLAG_SUBMITTED
          end

          attempt.response = r
          attempt.save
          return r
        end

        def self.process(team, data)
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: ::DateTime.now,
            request: data.to_s,
            response: ::Themis::Finals::Attack::Result::ERR_GENERIC,
            team_id: team.id,
            deprecated_api: false
          )

          internal_process(attempt, team, data)
        end

        def self.process_deprecated(team, data)
          attempt = ::Themis::Finals::Models::AttackAttempt.create(
            occured_at: ::DateTime.now,
            request: data.to_s,
            response: ::Themis::Finals::Attack::Result::ERR_GENERIC,
            team_id: team.id,
            deprecated_api: true
          )

          threshold =
            ::Time.now -
            ::Themis::Finals::Configuration.get_contest_flow.attack_limit_period

          attempt_count = ::Themis::Finals::Models::AttackAttempt.where(
            team: team,
            deprecated_api: true
          ).where(
            'occured_at >= ?',
            threshold.to_datetime
          ).count

          limit_attempts = \
            ::Themis::Finals::Configuration.get_contest_flow.attack_limit_attempts

          if attempt_count > limit_attempts
            r = ::Themis::Finals::Attack::Result::ERR_ATTEMPTS_LIMIT
            attempt.response = r
            attempt.save
            return r
          end

          internal_process(attempt, team, data)
        end
      end
    end
  end
end
