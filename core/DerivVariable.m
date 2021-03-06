classdef DerivVariable < handle
    properties
        values
        shape
    end
    properties(Dependent)
        order
    end
    methods
        function obj = DerivVariable(varargin)
            % values = {x^(0), x^(1), ... x^(order)}
            obj.values = varargin;
            obj.setShape(varargin{:});
        end
        
        function out = deriv(obj, order)
            assert(order >= 0,...
                "The order must be greater than or equal to 0.")
            if order > obj.order
                out = zeros(obj.shape);
                return
            end
            out = obj.values{1 + order};
        end
    end
    % set and get methods
    methods
        function setShape(obj, varargin)
%             DerivVariable.checkShapeCompatibility(varargin{:});
            obj.shape = size(varargin{1});
        end
        
        function setDeriv(obj, deriv, order, maintainOrder)
            if nargin < 4 || isempty(maintainOrder)
                maintainOrder = true;
            end
            if nargin < 3 || isempty(order)
                order = 1;
            end
            
            if isa(deriv, "numeric")
                obj.setDerivValue(deriv, order, maintainOrder);
            elseif isa(deriv, "DerivVariable")
                obj.setDerivVar(deriv, order, maintainOrder);
            end
        end
        
        function setDerivValue(obj, derivValue, order, maintainOrder)
            if nargin < 4 || isempty(maintainOrder)
                maintainOrder = true;
            end
            if nargin < 3 || isempty(order)
                order = 1;
            end
            assert(order >= 0,...
                "The order must be greater than or equal to 0.")
            if order > obj.order + 1
                return
            end
            if order > obj.order
                if maintainOrder
                    return
                end
            end
            
            obj.values{1 + order} = derivValue;
            obj.setShape(obj.values{:}, derivValue);
        end
        
        function setDerivVar(obj, derivVar, order, maintainOrder)
            if nargin < 4 || isempty(maintainOrder)
                maintainOrder = true;
            end
            if nargin < 3 || isempty(order)
                order = 1;
            end
            assert(order >= 0,...
                "The order must be greater than or equal to 0.")
            assert(isa(derivVar, "DerivVariable"),...
                "The derivVar must be an instance of DerivVariable.")
            if order > obj.order + 1
                return
            end
            
            if maintainOrder
                updatedValues = [...
                    obj.values(1:order),...
                    derivVar.values(1:1 + obj.order - order)];
            else
                updatedValues = [obj.values(1:order), derivVar.values];
            end
            obj.values = updatedValues;
        end
        
        function setValues(obj, varargin)
            obj.values = varargin;
            obj.setShape(varargin{:});
        end
        
        function out = get.order(obj)
            out = numel(obj.values) - 1;
        end
        
        function out = get(obj, varargin)
            newValues = cell(size(obj.values));
            for j = 1:numel(obj.values)
                temp = obj.values{j};
                newValues{j} = temp(varargin{:});
            end
            out = DerivVariable(newValues{:});
        end
        
        function out = flatValue(obj)
            d = prod(obj.shape);
            N = obj.order;
            out = nan(d*(1 + N), 1);
            
            startIndex = 0;
            for i = 1:N + 1
                out(startIndex + 1:startIndex + d, :) = obj.values{i};
                startIndex = startIndex + d;
            end
        end
    end
    
    % operator overloading and other oprators
    methods
        function out = plus(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = DerivPlus(obj1, obj2).forward();
        end
        
        function out = minus(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = DerivMinus(obj1, obj2).forward();
        end
        
        function out = uminus(obj)
            N = obj.order;
            newValues = cell(1, 1 + N);
            for n = 0:N
                newValues{1 + n} = -obj.deriv(n);
            end
            out = DerivVariable(newValues{:});
        end
        
        function out = uplus(obj)
            out = DerivVariable(obj.values{:});
        end
        
        function out = times(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = DerivTimes(obj1, obj2).forward();
        end
        
        function out = mtimes(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = DerivMtimes(obj1, obj2).forward();
        end
        
        function out = mrdivide(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = obj1*obj2.inverse();
        end
        
        function out = mldivide(obj1, obj2)
            obj1 = DerivVariable.wrapNumeric(obj1);
            obj2 = DerivVariable.wrapNumeric(obj2);
            
            out = obj1.inverse()*obj2;
        end
        
        function out = transpose(obj)
            N = obj.order;
            newValues = cell(1, 1 + N);
            for n = 0:N
                newValues{1 + n} = obj.deriv(n).';
            end
            out = DerivVariable(newValues{:});
        end
        
        function out = horzcat(varargin)
            N = 0;
            numVar = numel(varargin);
            for j = 1:numVar
                if isa(varargin{j}, 'DerivVariable')
                    N = max(N, varargin{j}.order);
                end
            end
            catvalues = cell(1, 1 + N);
            
            temp = cell(numVar, 1);
            for j = 1:numVar
                if isa(varargin{j}, 'DerivVariable')
                    temp{j} = varargin{j}.deriv(0);
                else
                    temp{j} = varargin{j};
                end
            end
            catvalues{1} = horzcat(temp{:});
            for n = 1:N
                for j = 1:numVar
                    if isa(varargin{j}, 'DerivVariable')
                        temp{j} = varargin{j}.deriv(n);
                    else
                        temp{j} = zeros(size(varargin{j}));
                    end
                end
                catvalues{1 + n} = horzcat(temp{:});
            end
            out = DerivVariable(catvalues{:});
        end
        
        function out = vertcat(varargin)
            N = 0;
            numVar = numel(varargin);
            for i = 1:numVar
                if isa(varargin{i}, 'DerivVariable')
                    N = max(N, varargin{i}.order);
                end
            end
            catvalues = cell(1, 1 + N);
            
            temp = cell(numVar, 1);
            for i = 1:numVar
                if isa(varargin{i}, 'DerivVariable')
                    temp{i} = varargin{i}.deriv(0);
                else
                    temp{i} = varargin{i};
                end
            end
            catvalues{1} = vertcat(temp{:});
            for n = 1:N
                for i = 1:numVar
                    if isa(varargin{i}, 'DerivVariable')
                        temp{i} = varargin{i}.deriv(n);
                    else
                        temp{i} = zeros(size(varargin{i}));
                    end
                end
                catvalues{1 + n} = vertcat(temp{:});
            end
            out = DerivVariable(catvalues{:});
        end
        
        % other operators
        function out = inverse(obj)
            out = DerivInverse(obj).forward();
        end
        
        function out = norm(obj)
            assert(numel(obj.shape) == 2,...
                "Only the norm of a row vector or column vector can be used.")
            assert(obj.shape(2) == 1 || obj.shape(1) == 1,...
                "Only the norm of a row vector or column vector can be used.")
            normSqVar = obj.'*obj;
            out = PowerDeriv(1/2).forward(normSqVar);
        end
        
        function out = normalize(obj)
            out = obj/obj.norm();
        end
        
        function out = hat(obj)
            assert(all(obj.shape == [3, 1]),...
                "The shape of the vector should be [3, 1]")
            N = obj.order;
            newValues = cell(1, 1 + N);
            for n = 0:N
                v = obj.deriv(n);
                v_hat = [...
                    0, -v(3), v(2);
                    v(3), 0, -v(1);
                    -v(2), v(1), 0];
               newValues{1 + n} = v_hat;
            end
            out = DerivVariable(newValues{:});
        end
        
        function out = cross(obj1, obj2)
            assert(all(obj1.shape == [3, 1]),...
                "The shape of the vector should be [3, 1]")
            assert(all(obj2.shape == [3, 1]),...
                "The shape of the vector should be [3, 1]")
            out = obj1.hat()*obj2;
        end
        
        function out = mpower(obj, r)
            assert(all(obj.shape == [1, 1]),...
                "The argument for mpower() should be a scalar")
            out = PowerDeriv(r).forward(obj);
        end
        
        function out = sqrt(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for sqrt() should be a scalar")
            out = PowerDeriv(1/2).forward(obj);
        end
        
        function out = exp(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for exp() should be a scalar")
            out = ExpDeriv().forward(obj);
        end
        
        function out = log(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for log() should be a scalar")
            out = LogDeriv().forward(obj);
        end
        
        function out = sin(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for sin() should be a scalar")
            out = SinDeriv().forward(obj);
        end
        
        function out = cos(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for cos() should be a scalar")
            out = CosDeriv().forward(obj);
        end
        
        function out = tan(obj)
            assert(all(obj.shape == [1, 1]),...
                "The argument for tan() should be a scalar")
            out = obj.sin()/obj.cos();
        end
    end
    
    methods(Static)
        function out = wrapNumeric(value)
            if isa(value, 'numeric')
                out = DerivVariable(value);
            elseif isa(value, 'DerivVariable')
                out = value;
            end
        end
        
        function checkShapeCompatibility(varargin)
            if numel(varargin) < 2
                return
            end
            shape = size(varargin{1});
            for i = 1:numel(varargin)
                assert(all(size(varargin{i}) == shape),...
                    "The size for each value is not consistent.");
            end
        end
        
        function test()
            clc
            
            fprintf("== Test for DerivVariable == \n")
            fprintf("t = 2 \n")
            fprintf("x = [1; t] \n")
            
            t = 2;
            
            fprintf("1. Using forward methods \n")
            var = DerivVariable(...
                [1; t], [0; 1], [0; 0]);
            normVar = norm(var);
            fprintf("[normVar.deriv(0), normVar.deriv(1), normVar.deriv(2)]: \n")
            disp([normVar.deriv(0), normVar.deriv(1), normVar.deriv(2)])
            
            fprintf("2. Analytic result \n")
            z = (1 + t^2)^(1/2);
            z_dot = t/(1 + t^2)^(1/2);
            z_2dot = 1/(1 + t^2)^(3/2);
            fprintf("[deriv(0), deriv(1), deriv(2)]: \n")
            disp([z, z_dot, z_2dot])
        end
    end
end